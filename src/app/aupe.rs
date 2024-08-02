use rand::{thread_rng, Rng};
use structopt::StructOpt;

use crate::net::{App, PeerRef, Network};
use crate::net::Metrics as NetMetrics;
use crate::util::{either_or_if_both, hash, sample, sample_nocopy,  get_min_key_value, print_samples};
use crate::rps::RPS;
use crate::graph::ByzConnGraph;
use crate::GLOBAL_OMNISCIENT_FREQ_ARRAY;

const DEBUG: bool = false;

pub enum Msg {
    SelfNotif,
    PullRequest,
    PullReply(Vec<PeerRef>),
    PushRequest,

    MergeRequest(Vec<isize>),
    MergeReply(Vec<isize>),
}

#[derive(Clone, Default, StructOpt, Debug)]
pub struct Init {
    /// Number of nodes
    #[structopt(short = "n", long = "nodes")]
    pub nodes: usize,

    /// Number of SGX nodes
   /*  #[structopt(short = "x", long = "trusted-nodes")]
    pub n_trusted: usize,
 */
    /// Number of Byzantine nodes
    #[structopt(short = "t", long = "num-byzantines")]
    pub n_byzantine: usize,

    /// Byzantine flood factor
    #[structopt(short = "f", long = "byzantine-flood-factor")]
    pub byzantine_flood_factor: usize,

    /// Byzantine attack start time
    #[structopt(short = "s", long = "attack-start-time", default_value = "0")]
    pub attack_start_time: u64,

    /// Replacement frequency: replace k samples every r (this paramter) time units
    #[structopt(short = "r", long = "replacement-frequency")]
    pub replacement_frequency: Option<u64>,

    /// Replacement count: replace k (this parameter) samples every r time units
    #[structopt(short = "k", long = "replacement-count", default_value = "1")]
    pub replacement_count: usize,

    /// Peer sampling view size
    #[structopt(short = "v", long = "view-size")]
    pub view_size: usize,

    /// Peer sampling uniform-corrected view size
    #[structopt(short = "u", long = "sample-size")]
    pub sample_view_size: usize,

    /// Sample memory size for the unbiaing strategy
    #[structopt(short = "m", long = "memory-size")]
    pub memory_size: usize,

    /// Enable detailed graph statistics
    #[structopt(short = "G", long = "graph-stats", default_value = "nograph")]
    pub graph_stats: WhichGraphStats,

    /// Use merge with omniscient strategy
    #[structopt(short = "O", long = "use-omn-merge")]
    pub use_omn_merge: bool,
    /// Use merge with omniscient strategy
    #[structopt(short = "L", long = "use-omn-global")]
    pub use_omn_global: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub enum WhichGraphStats {
    NoGraph,
    View,
    Samples,
    ViewSamples,
}

impl Default for WhichGraphStats {
    fn default() -> Self {
        Self::NoGraph
    }
}

impl std::str::FromStr for WhichGraphStats {
    type Err = &'static str;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "view" => Ok(Self::View),
            "samples" => Ok(Self::Samples),
            "view+samples" => Ok(Self::ViewSamples),
            "nograph" => Ok(Self::NoGraph),
            _ => Err("invalid which graph"),
        }
    }
}

pub struct Aupe {
    params: Init,

    my_id: PeerRef,
    is_byzantine: bool,

    view: Vec<PeerRef>,
    push_view: Vec<PeerRef>,
    pull_view: Vec<PeerRef>,
    sample_part: Vec<PeerRef>,
    
    sample_view: Vec<(u64, Option<PeerRef>)>,

    out_samples: Vec<PeerRef>,

    v_pull: Vec<PeerRef>,
    v_push: Vec<PeerRef>,

    n_received: usize,
    n_byzantine_received: usize,

    omniscient_freq_array: Vec<isize>,
    omniscient_memory: Vec<PeerRef>,
    minkey: PeerRef,
    minvalue: isize,
    n_discovered: usize,
}

pub struct Metrics {
    n_procs: usize,

    n_byzantine_received: usize,
    n_received: usize,
    
    n_byzantine_neighbors: usize,
    n_pushed_byzantine_neighbors: f64,
    n_pulled_byzantine_neighbors: f64,
    n_sampled_byzantine_neighbors: f64,
    n_isolated: usize,

    n_byzantine_samples: usize,
    min_byzantine_samples: Option<i64>,
    max_byzantine_samples: Option<i64>,
    n_fullbyz: usize,

    n_fbi: usize,

    graph: ByzConnGraph,
}


impl NetMetrics for Metrics {
    fn empty() -> Self {
        Metrics {
            n_procs: 0,
            n_byzantine_received: 0,
            n_received: 0,
            n_byzantine_neighbors: 0,
            n_pushed_byzantine_neighbors: 0.0,
            n_pulled_byzantine_neighbors: 0.0,
            n_sampled_byzantine_neighbors: 0.0,
            n_isolated: 0,
            n_byzantine_samples: 0,
            min_byzantine_samples: None,
            max_byzantine_samples: None,
            n_fullbyz: 0,
            n_fbi: 0,
            graph: ByzConnGraph::new(),
        }
    }
    fn net_combine(&mut self, other: &Self) {
        self.n_procs += other.n_procs;

        self.n_byzantine_received += other.n_byzantine_received;
        self.n_received += other.n_received;

        self.n_byzantine_neighbors += other.n_byzantine_neighbors;
        self.n_pushed_byzantine_neighbors += other.n_pushed_byzantine_neighbors;
        self.n_pulled_byzantine_neighbors += other.n_pulled_byzantine_neighbors;
        self.n_sampled_byzantine_neighbors += other.n_sampled_byzantine_neighbors;

        self.n_isolated += other.n_isolated;

        self.n_byzantine_samples += other.n_byzantine_samples;
        self.max_byzantine_samples = either_or_if_both(
            &self.max_byzantine_samples,
            &other.max_byzantine_samples,
            |a, b| std::cmp::max(*a, *b));
        self.min_byzantine_samples = either_or_if_both(
            &self.min_byzantine_samples,
            &other.min_byzantine_samples,
            |a, b| std::cmp::min(*a, *b));
        self.n_fullbyz += other.n_fullbyz;

        self.n_fbi += other.n_fbi;

        self.graph.combine(&other.graph);
    }
    fn headers() -> Vec<&'static str> {
        vec![
            "avgRecv",
            "avgByzRecv",
            "pByzRecv",
            "avgByzN",
            "pushByzN",
            "pullByzN",
            "sampByzN",
            "n_isolated",
            "avgByzSamp",
            "min",
            "max",
            "n_fullbyz",
            "n_fbi",
            "cluscoeff",
            "MPL",
            "id_min", "id_d1", "id_q1", "id_med", "id_q3", "id_d9", "id_max",
        ]
    }
    fn values(&self) -> Vec<String> {
        // Clustering coefficient
        let cluscoeff = self.graph.clustering_coeff();

        // In-degree quartiles (for correct nodes)
        let ind = self.graph.indegree_dist(self.n_procs);

        // Average path length estimation
        let mpl = self.graph.mean_path_length(self.n_procs);

        vec![
            format!("{:.2}",
                   (self.n_received as f32) / (self.n_procs as f32)),
            format!("{:.2}",
                   (self.n_byzantine_received as f32) / (self.n_procs as f32)),
            format!("{:.4}",
                   (self.n_byzantine_received as f32) / (self.n_received as f32)),
            format!("{:.2}",
                   (self.n_byzantine_neighbors as f32) / (self.n_procs as f32)),
            format!("{:.2}",
                   (self.n_pushed_byzantine_neighbors as f32) / (self.n_procs as f32)),
            format!("{:.2}",
                   (self.n_pulled_byzantine_neighbors as f32) / (self.n_procs as f32)),
            format!("{:.2}",
                   (self.n_sampled_byzantine_neighbors as f32) / (self.n_procs as f32)),

            format!("{}", self.n_isolated),
            format!("{:.2}",
                (self.n_byzantine_samples as f32) / (self.n_procs as f32)),
            format!("{}", self.min_byzantine_samples.unwrap_or(-1)),
            format!("{}", self.max_byzantine_samples.unwrap_or(-1)),
            format!("{}", self.n_fullbyz),
            format!("{}", self.n_fbi),

            format!("{:.4}", cluscoeff),
            format!("{:.4}", mpl),
            format!("{}", ind[0]),
            format!("{}", ind[ind.len()/10]),
            format!("{}", ind[ind.len()/4]),
            format!("{}", ind[ind.len()/2]),
            format!("{}", ind[3*ind.len()/4]),
            format!("{}", ind[9*ind.len()/10]),
            format!("{}", ind[ind.len()-1]),
        ]
    }
}


type Net<'a> = &'a mut dyn Network<Msg>;


impl Aupe {
    fn update_samples(&mut self, candidates: &[PeerRef]) {
        //println!("len {}", self.sample_view.len());
        for i in 0..self.sample_view.len() {
            self.update_sample(i, candidates);
        }
    }

    fn update_sample(&mut self, i: usize, candidates: &[PeerRef]) {
        let (seed, selected) = &mut self.sample_view[i];
        let mut prev_hash = selected.map(|p| hash(*seed, p));

        for candidate in candidates.iter() {
            let new_hash = hash(*seed, *candidate);
            if prev_hash.is_none() || new_hash < prev_hash.unwrap() {
                *selected = Some(*candidate);
                prev_hash = Some(new_hash);
            }
        }
    }


    fn debiais_stream_with_omni(&mut self, inputstream: Vec<usize>) -> Vec<usize> {
        let mut outputstream = Vec::new();
        //println!("++");
        let mut rng = thread_rng();
        let mut shuffled_input = inputstream.to_vec();
        rng.shuffle(&mut shuffled_input[..]);
        let vec = GLOBAL_OMNISCIENT_FREQ_ARRAY.get().unwrap().write().unwrap();
        for element in &shuffled_input {
            let mut occur = vec[*element];
            if !self.params.use_omn_global {
                occur = self.omniscient_freq_array[*element];
            }
            
            if self.minvalue > occur { // new minval
                self.minvalue = occur;
                self.minkey = *element;
            }else if *element == self.minkey { // search min if it was him
                if self.params.use_omn_global {
                    if let Some((min_index, min_value)) = get_min_key_value(&vec) {
                        if self.my_id == 9 && DEBUG{
                            eprintln!("Minimum value: {}, at index: {}", min_value, min_index);
                        }
                        self.minvalue = min_value;
                        self.minkey = min_index; 
                    } else {
                        println!("The vector is empty.");
                    }  
                }else{
                    if let Some((min_index, min_value)) = get_min_key_value(&self.omniscient_freq_array) {
                        if self.my_id == 9 && DEBUG{
                            eprintln!("Minimum value: {}, at index: {}", min_value, min_index);
                        }
                        self.minvalue = min_value;
                        self.minkey = min_index; 
                    } else {
                        println!("The vector is empty.");
                    }  
                }
            }
            if self.omniscient_memory.len() < self.params.memory_size {
                if !self.omniscient_memory.contains(element) {
                    self.omniscient_memory.push(*element);
                }
            }else {
                let prob = self.minvalue as f64/ occur as f64;
                let random_float: f64 = rand::thread_rng().gen(); 
                if random_float < prob && !self.omniscient_memory.contains(element) {
                    let i = rng.gen_range(0, self.params.memory_size);//omniscient_memory.len());
                    if let Some(tobereplaced) = self.omniscient_memory.get_mut(i) {
                        *tobereplaced = *element;
                    } else {
                        println!("Index out of bounds");
                    }
                }
            }
            let i = rng.gen_range(0, self.omniscient_memory.len());
            outputstream.push(self.omniscient_memory[i].clone());
        }
            
        outputstream
    }
    fn merge_knowledge_both_ways(&mut self, other_omniscient_freq_array: Vec<isize>) {
        if self.my_id == 9 && DEBUG{
            println!("**********merge_knowledge_both_ways*********");
            println!("Omniscient_freq_array {:?} of node { }",
                self.omniscient_freq_array, self.my_id);
            println!("other omniscient_freq_array {:?}", other_omniscient_freq_array);
        }
        
        if DEBUG {
            eprintln!("Merge");
        }

        for id in 0..self.params.nodes {
            let mut average_freq;
            if self.omniscient_freq_array[id] <=0 && other_omniscient_freq_array[id] <=0 {
                average_freq = -1; // Both didn't see the node
            } else{
                average_freq = ((std::cmp::max(self.omniscient_freq_array[id], 0) + 
                    std::cmp::max(other_omniscient_freq_array[id], 0)) as f64 / 2.0) as isize;
                average_freq = std::cmp::max(average_freq, 1);
            }
            
            self.omniscient_freq_array[id] = average_freq;
        }
        if self.my_id == 9 && DEBUG{
            eprintln!("NEW Omniscient_freq_array {:?} of node { }",
                self.omniscient_freq_array, self.my_id);
        }
        
    }

}

impl App for Aupe {
    type Init = Init;
    type Msg = Msg;
    type Metrics = Metrics;

    fn new() -> Self {
        Self {
            params: Init::default(),

            my_id: 0,
            is_byzantine: false,
            view: Vec::new(),
            push_view: Vec::new(),
            pull_view: Vec::new(),
            sample_part: Vec::new(),
            sample_view: Vec::new(),
            out_samples: Vec::new(),

            v_push: Vec::new(),
            v_pull: Vec::new(),

            n_received: 0,
            n_byzantine_received: 0,

            omniscient_freq_array: Vec::new(),
            omniscient_memory: Vec::new(),
            minkey: 0,
            minvalue: std::isize::MAX,
            n_discovered: 0,
        }
    }
    
    fn init(&mut self, id: PeerRef, net: Net, init: &Self::Init) {
        self.my_id = id;
        self.params = init.clone();
    
        // Init preallocated vectors
        if !self.params.use_omn_global{
            self.omniscient_freq_array = vec![-1; self.params.nodes];
        }
        self.is_byzantine = id < init.n_byzantine;
        if !self.is_byzantine {
            let view = net.sample_peers(self.params.view_size);

            let mut rng = thread_rng();
            self.sample_view = (0..self.params.sample_view_size)
                .map(|_| (rng.gen_range(0, std::u64::MAX), None)).collect();
            self.update_samples(&view[..]);
            self.view = view;
            // Update tracking component
            if self.params.use_omn_global{
                let mut vec = GLOBAL_OMNISCIENT_FREQ_ARRAY.get().unwrap().write().unwrap();
                for item in self.view.clone() {
                    let max_value = std::cmp::max(vec[item.clone()] +1, 
                        1);
                    vec[item.clone()] = max_value;
                }
            }else{
                for item in self.view.clone() {
                    let max_value = std::cmp::max(self.omniscient_freq_array[item.clone()] +1, 
                        1);
                    self.omniscient_freq_array[item.clone()] = max_value;
                }
            }
            
        }
        net.send(id, Msg::SelfNotif);
    }

    
    fn handle(&mut self, net: Net, from: PeerRef, msg: &Self::Msg) {
        //println!("**********************Node {}**********************", self.my_id);
        if self.is_byzantine {
            let mut byzantines = (0..self.params.n_byzantine).collect::<Vec<_>>();
            match msg {
                Msg::SelfNotif => {
                    //println!("message b SN ");
                    //println!("indexes {:?} ", net.sample_peers(self.params.byzantine_flood_factor));
                    net.send(self.my_id, Msg::SelfNotif);
                    if net.time() >= self.params.attack_start_time {
                        net.sample_peers(self.params.byzantine_flood_factor)
                            .iter()
                            .for_each(|p| net.send(*p, Msg::PushRequest));
                    }
                },
                Msg::PullRequest => {
                    //println!("message b PlRq ");
                    //println!("byzview {:?} ", sample_nocopy(&mut byzantines[..], self.params.view_size));
                    net.send(from, Msg::PullReply(sample_nocopy(&mut byzantines[..], self.params.view_size)));
                },
                _ => (),
            }
        } else {
            match msg {
                Msg::SelfNotif => {
                    //println!("message SN ");
                    if let Some(rf) = self.params.replacement_frequency {
                        if (self.my_id as u64 + net.time()) % rf == 0 {
                            let mut rng = thread_rng();
                            let view = self.view.clone();
                            let sample_view = self.sample_view.iter()
                                .filter(|(_, x)| x.is_some())
                                .map(|(_, x)| x.unwrap())
                                .collect::<Vec<_>>();
                            for k in 0..self.params.replacement_count {
                                let i_replace = ((net.time() / rf) as usize * self.params.replacement_count + k) % self.sample_view.len();
                                if let Some(sample) = self.sample_view[i_replace].1 {
                                    if self.out_samples.len() < 200 {
                                        self.out_samples.push(sample);
                                    }
                                }
                                self.sample_view[i_replace].0 = rng.gen_range(0, std::u64::MAX);
                                self.update_sample(i_replace, &view[..]);
                                self.update_sample(i_replace, &sample_view[..]);
                            }
                        }
                    }
                    if self.my_id == self.params.nodes-1 && DEBUG{
                        //println!("vpush{:?} vpull{:?}",self.v_push, self.v_pull);
                        eprintln!("vpush({}) vpull({})",self.v_push.len(), self.v_pull.len());
                    }
                    //
                    if !self.v_push.is_empty() && !self.v_pull.is_empty() {
                        
                        if self.my_id == self.params.nodes-1 && DEBUG{
                            //println!("vpush{:?} vpull{:?}",self.v_push, self.v_pull);
                            println!("vpush({}) vpull({})", self.v_push.len(), self.v_pull.len());
                        }
                        let mut v_push = std::mem::replace(&mut self.v_push, Vec::new());
                        let mut v_pull = std::mem::replace(&mut self.v_pull, Vec::new());
                        
                        self.update_samples(&v_push);
                        self.update_samples(&v_pull);

                        v_push = self.debiais_stream_with_omni(v_push);
                        v_pull = self.debiais_stream_with_omni(v_pull);
                        
                        if self.my_id == 9 && DEBUG{
                            eprintln!("AFTER debiasing vpush{:?} vpull{:?}",v_push, v_pull);
                        }

                        self.push_view = sample(&v_push[..], self.params.view_size / 3);
                        self.pull_view = sample(&v_pull[..], self.params.view_size / 3);
                        
                        let mut view = self.push_view.clone();
                        view.extend(self.pull_view.clone());

                        let samples_peer = self.sample_view.iter()
                            .filter(|(_, x)| x.is_some())
                            .map(|(_, x)| x.unwrap())
                            .collect::<Vec<_>>();
                        self.sample_part = sample(&samples_peer[..], self.params.view_size - view.len());
                        
                        view.extend(self.sample_part.clone());

                        view.extend(sample(&self.view[..], self.params.view_size - view.len()));
                        self.view = view;

                    }
                    
                    if self.my_id == 9 && DEBUG{
                        eprintln!("View Node{} {:?} : push {:?} pull {:?} sample {:?}", 
                            self.my_id, self.view, self.push_view, self.pull_view, self.sample_part);
                        print_samples(&mut self.sample_view);
                    }

                    if self.my_id == self.params.nodes-1 && DEBUG{
                        if self.params.use_omn_global{
                            let vec = GLOBAL_OMNISCIENT_FREQ_ARRAY.get().unwrap().read().unwrap();
                            println!("omniscient_freq_array {:?} of node { }",
                            *vec, self.my_id);
                        }else{
                            println!("omniscient_freq_array {:?} of node { }",
                            self.omniscient_freq_array, self.my_id);
                            println!("n_discoverd = { }", self.n_discovered);
                        }
                        println!("sample memory {:?} of node { }",
                            self.omniscient_memory, self.my_id);
                        println!("The key with the minimum value is '{}' with a value of {}.", 
                            self.minkey, self.minvalue);
                    }
                    if self.params.use_omn_merge {
                        sample(&self.view[..], 1).iter()
                        .for_each(|p| {
                            net.send(*p, Msg::PushRequest);
                            net.send(*p, Msg::MergeRequest(self.omniscient_freq_array.clone())) 
                        });

                        sample(&self.view[..], 1).iter()
                            .for_each(|p| {
                                net.send(*p, Msg::PullRequest);
                                net.send(*p, Msg::MergeRequest(self.omniscient_freq_array.clone()))
                            });
                    }else{
                        sample(&self.view[..], 1).iter()
                        .for_each(|p| {
                            net.send(*p, Msg::PushRequest)
                        });

                    sample(&self.view[..], 1).iter()
                        .for_each(|p| {
                            net.send(*p, Msg::PullRequest)
                        });
                    }
                    

                    net.send(self.my_id, Msg::SelfNotif);
                },
                Msg::PullRequest => {
                    //println!("message PlRq ");
                    net.send(from, Msg::PullReply(self.view.clone()));
                },
                Msg::PullReply(lst) => {
                    if self.my_id == 9 && DEBUG{
                        eprintln!("message PlRy from {} : {:?}", 
                        from.to_string(), lst);
                    }
                    self.n_received += lst.len();
                    self.n_byzantine_received += lst.iter()
                        .filter(|x| **x < self.params.n_byzantine)
                        .count();
                    self.v_pull.extend(lst);
                    
                    if self.params.use_omn_global{
                        let mut vec = GLOBAL_OMNISCIENT_FREQ_ARRAY.get().unwrap().write().unwrap();
                        for item in lst {
                            let max_value = std::cmp::max(vec[item.clone()] +1, 
                                1);
                            vec[item.clone()] = max_value;
                        }
                    }else{
                        for item in lst {
                            if self.omniscient_freq_array[item.clone()] == -1 {
                                self.n_discovered += 1;
                                self.omniscient_freq_array[item.clone()] = 1;
                            } else {
                                self.omniscient_freq_array[item.clone()] += 1;
                            }
                        }
                    }
                },
                Msg::PushRequest => {
                    if self.my_id == 9 && DEBUG{
                        eprintln!("message PushR from {} ", from.to_string());
                    }
                    self.n_received += 1;
                    if from < self.params.n_byzantine {
                        self.n_byzantine_received += 1;
                    }
                    self.v_push.push(from);

        
                    if self.params.use_omn_global{
                        let mut vec = GLOBAL_OMNISCIENT_FREQ_ARRAY.get().unwrap().write().unwrap();
                        let max_value = std::cmp::max(vec[from.clone()] +1, 
                            1);
                        vec[from.clone()] = max_value;

                    }else{
                        if self.omniscient_freq_array[from.clone()] == -1 {
                            self.n_discovered += 1;
                            self.omniscient_freq_array[from.clone()] = 1;
                        } else {
                            self.omniscient_freq_array[from.clone()] += 1;
                        }
                    }
               
                },
                Msg::MergeRequest(lst) => {
                    if self.params.use_omn_merge{
                        if self.my_id == 9 && DEBUG{
                            eprintln!("message MergeRq from {}", from.to_string());
                        }
                        net.send(from, Msg::MergeReply(self.omniscient_freq_array.clone())); //send its array before merging
                        self.merge_knowledge_both_ways(lst.to_vec());
                    }else{
                        if self.my_id == 9 && DEBUG{
                            eprintln!("NO MERGE");
                        }
                    }
                },
                Msg::MergeReply(lst) => {
                    if self.params.use_omn_merge{
                        if self.my_id == 9 && DEBUG{
                            eprintln!("message MergeRy from {}", from.to_string());
                        }
                        self.merge_knowledge_both_ways(lst.to_vec());
                    }else{
                        if self.my_id == 9 && DEBUG{
                            eprintln!("NO MERGE");
                        }
                    }
                },
            }
        }
    }

    fn metrics(&mut self, _net: Net) -> Self::Metrics {
        if self.is_byzantine {
            let mut metrics = Self::Metrics::empty();

            if self.params.graph_stats != WhichGraphStats::NoGraph {
                let neighs = (0..self.params.n_byzantine).collect::<Vec<_>>();
                metrics.graph = ByzConnGraph::peer_new(self.params.n_byzantine,
                                                       self.my_id,
                                                       neighs);
            }

            metrics
        } else {
            let nbn = self.view.iter().filter(|x| **x < self.params.n_byzantine).count();
            let mut nbpush = 0.0;
            let mut nbpull = 0.0;
            let mut nbsamp = 0.0;
            if self.push_view.len() !=0 {
                nbpush = self.push_view.iter().filter(|x| **x < self.params.n_byzantine).count() as f64;
                nbpush = nbpush / (self.push_view.len() as f64);
            }
            if self.pull_view.len() !=0 {
                nbpull = self.pull_view.iter().filter(|x| **x < self.params.n_byzantine).count() as f64;
                nbpull = nbpull / (self.pull_view.len() as f64);
            }
            if self.sample_part.len() !=0 {
                nbsamp = self.sample_part.iter().filter(|x| **x < self.params.n_byzantine).count() as f64;
                nbsamp = nbsamp / (self.sample_part.len() as f64);
            }
            
            let samp = self.sample_view.iter()
                .filter(|(_, x)| x.is_some());
            let nsamp = samp.clone().count();
            let nbs = samp.filter(|(_, x)| x.unwrap() < self.params.n_byzantine).count();

            if self.my_id == self.params.nodes-1 && DEBUG{
                eprintln!("nbn={}/{} nbpush={} nbpull={} nbsamp={} nbs={}/{}",
                nbn, self.view.len(),
                nbpush, nbpull, nbsamp, 
                nbs, self.sample_view.len());
            }

            let graph = match self.params.graph_stats {
                WhichGraphStats::NoGraph => ByzConnGraph::new(),
                WhichGraphStats::View => {
                    let neighs = self.view.clone();
                    ByzConnGraph::peer_new(self.params.n_byzantine, self.my_id, neighs)
                }
                WhichGraphStats::Samples => {
                    let neighs = self.sample_view.iter().filter(|(_, x)| x.is_some())
                                  .map(|(_, x)| x.unwrap())
                                  .collect::<Vec<_>>();
                    ByzConnGraph::peer_new(self.params.n_byzantine, self.my_id, neighs)
                }
                WhichGraphStats::ViewSamples => {
                    let mut neighs = self.view.clone();
                    neighs.extend(self.sample_view.iter().filter(|(_, x)| x.is_some())
                                  .map(|(_, x)| x.unwrap()));
                    ByzConnGraph::peer_new(self.params.n_byzantine, self.my_id, neighs)
                },
            };

            let ret = Self::Metrics{
                n_procs: 1,
                n_received: self.n_received,
                n_byzantine_received: self.n_byzantine_received,
                n_byzantine_neighbors: nbn,
                n_pushed_byzantine_neighbors: nbpush,
                n_pulled_byzantine_neighbors: nbpull,
                n_sampled_byzantine_neighbors: nbsamp,
                n_isolated: if nbn == self.view.len() { 1 } else { 0 },
                n_byzantine_samples: nbs,
                min_byzantine_samples: Some(nbs as i64),
                max_byzantine_samples: Some(nbs as i64),
                n_fullbyz: if nbs == nsamp { 1 } else { 0 },
                n_fbi: if nbn == self.view.len() && nbs == nsamp { 1 } else { 0 },
                graph,
            };
            self.n_received = 0;
            self.n_byzantine_received = 0;
            /* self.v_pull=Vec::new();
            self.v_push=Vec::new(); */
          
            ret
        }
    }
}

impl RPS for Aupe {
    fn get_samples(&mut self) -> Vec<PeerRef> {
        std::mem::replace(&mut self.out_samples, Vec::new())
    }
    fn clear_samples(&mut self) {
        self.out_samples.clear();
    }
}
