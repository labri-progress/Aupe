use rand::{rng, Rng};
use structopt::StructOpt;

use crate::net::{App, PeerRef, Network};
use crate::net::Metrics as NetMetrics;
use crate::util::{either_or_if_both, hash, sample, sample_nocopy, write_results};
use crate::util::{ get_min_key_value, print_samples, print_vector_with_two_digits, 
    sample_exclude, vec_to_string, string_to_vec};
use crate::graph::ByzConnGraph;

use super::kvs::Kvs;
use super::cf::CF;

const DEBUG: bool = false;
pub enum Msg {
    SelfNotif,
    PullRequest,
    PullReply(Vec<PeerRef>),
    PushRequest,
    MergeRequest(usize, String),
    MergeReply(usize, String),
}

#[derive(Clone, Default, StructOpt, Debug)]
pub struct Init {
    /// Number of nodes
    #[structopt(short = "n", long = "nodes")]
    pub nodes: usize,

    /// Number of Byzantine nodes
    #[structopt(short = "t", long = "num-byzantines")]
    pub n_byzantine: usize,

    /// Byzantine flood factor
    #[structopt(short = "f", long = "byzantine-flood-factor")]
    pub byzantine_flood_factor: usize,

    /// Byzantine attack start time
    #[structopt(short = "s", long = "attack-start-time", default_value = "0")]
    pub attack_start_time: u64,

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
    
    // Cold filter
    #[structopt(short = "a", long = "threshold_layer_1", default_value = "15")]
    pub t1: u32,
    /// Threshold value of layer 2
    #[structopt(short = "b", long = "threshold_layer_2", default_value = "31")]
    pub t2: u32,
    /// number_of_hash_function of layer i
    #[structopt(short = "i", long = "layer_i_number_of_hash_functions", default_value = "3")]
    pub replicates: usize,
    /// Number_of_discrete_values of layer 1
    #[structopt(long = "w1", default_value = "10000")] //10000
    pub counter1: usize,
    /// Number_of_discrete_values of layer 2
    #[structopt(long = "w2", default_value = "245")]
    pub counter2: usize,
    /// number_of_hash_function
    #[structopt(short = "h", long = "number_of_hash_functions", default_value = "3")]
    pub depth: usize,
    /// Number_of_discrete_values
    #[structopt(short = "w", long = "number_of_discrete_values", default_value = "100")]
    pub width: usize,

    /// Number of SGX nodes
    #[structopt(short = "x", long = "trusted-nodes")]
    pub n_trusted: usize,

    /// How many sup merges should be used
    #[structopt(short = "p", long = "nb_merges")]
    pub nb_merge: usize,
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
    is_trusted: bool,

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

    sketch: CF, //Kvs,
    to_conctact: Vec<PeerRef>,
    oldest: PeerRef,
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

    fn update_contact(&mut self, item: PeerRef) {
        if self.is_trusted && self.params.nb_merge !=0 {
            if self.is_trusted(item) && item != self.my_id{
                if !self.to_conctact.contains(&item) {
                    if self.to_conctact.len() < self.params.nb_merge {
                        self.to_conctact.push(item.clone());
                    }else{ //full
                        if self.my_id == self.params.n_trusted + self.params.n_byzantine -1  && DEBUG{
                            println!("id_oldest {:?}", self.to_conctact.get_mut(self.oldest));
                        }
                        if let Some(to_be_replaced) = self.to_conctact.get_mut(self.oldest) {
                            *to_be_replaced = item;
                            self.oldest +=1; // update oldest id in to_contact list
                            self.oldest = self.oldest % (self.params.nb_merge );
                        }
                    }
                } 
            }
            /* println!("Node { } : to_contacted({:?}) M={} oldest=Node{}",self.my_id,
                            self.to_conctact, self.params.nb_merge, self.oldest); */
        }
    }

    fn is_trusted(&self, id:PeerRef) -> bool {
        return id >= self.params.n_byzantine && id < self.params.n_byzantine + self.params.n_trusted;
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
            is_trusted: false,

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

            sketch: CF::new(), //Kvs::new(),
            to_conctact: Vec::new(),
            oldest: 0,
        }
    }
    
    fn init(&mut self, id: PeerRef, net: Net, init: &Self::Init) {
        self.my_id = id;
        self.params = init.clone();

        // Init preallocated vectors
        self.sketch.init(self.params.nodes, self.params.clone());

        self.is_byzantine = id < init.n_byzantine;
        self.is_trusted = self.is_trusted(id); // F to F + T-1

        if !self.is_byzantine {
            let view = net.sample_peers(self.params.view_size);

            let mut rng = rng();

            self.sample_view = (0..self.params.sample_view_size)
                .map(|_| (rng.random_range(0..std::u64::MAX), None)).collect();
            self.update_samples(&view[..]);
            self.view = view;

            self.sketch.update_freq(self.view.clone());
            self.sketch.debiais_stream(self.view.clone());
        }

        if self.is_trusted && self.params.nb_merge != 0{
            let trusted_nodes = (self.params.n_byzantine..self.params.n_trusted+self.params.n_byzantine).collect::<Vec<_>>();

            // update trusted list with view   
            for item in self.view.clone() {
                self.update_contact(item.clone()); 
            }

            if self.my_id == self.params.n_trusted + self.params.n_byzantine -1  && DEBUG{
                println!("intermediaire CONTACT {:?}", self.to_conctact);
            }
            let missing_len = self.params.nb_merge - self.to_conctact.len();
            // select missing trusted neighbors and avoid himself
            if missing_len > 0 {
                sample_exclude::<usize>( trusted_nodes, &mut self.to_conctact, 
                    missing_len , self.my_id);
            }
            if self.my_id == self.params.n_trusted + self.params.n_byzantine -1  && DEBUG{
                println!("Node { } : to_contacted({:?}) M={} oldest=Node{}",self.my_id,
                    self.to_conctact, self.params.nb_merge, self.oldest);
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
                    net.send(self.my_id, Msg::SelfNotif);
                    if net.time() >= self.params.attack_start_time {
                        net.sample_peers(self.params.byzantine_flood_factor)
                            .iter()
                            .for_each(|p| net.send(*p, Msg::PushRequest));
                    }
                },
                Msg::PullRequest => {
                    net.send(from, Msg::PullReply(sample_nocopy(&mut byzantines[..], self.params.view_size)));
                },
                _ => (),
            }
        } else {
            match msg {
                Msg::SelfNotif => {
                    
                    //println!("vpush{:?} vpull{:?}",self.v_push, self.v_pull);
                    if !self.v_push.is_empty() && !self.v_pull.is_empty() {
                        
                        let mut v_push = std::mem::replace(&mut self.v_push, Vec::new());
                        let mut v_pull = std::mem::replace(&mut self.v_pull, Vec::new());

                        // Log real trace
                        let mut bags = v_push.clone();
                        bags.extend(v_pull.clone());

                        /* let file_path = String::from("aupe")+&self.params.n_byzantine.to_string() +"/node"
                            +&self.my_id.to_string() + ".txt";
                        match write_results(bags.clone(), &file_path) {
                            Ok(()) => {}
                            Err(e) => {
                                eprintln!("Error occurred: {} on {}", e, file_path); 
                            }
                        };  */
                        
                        v_push = self.sketch.debiais_stream(v_push);
                        v_pull = self.sketch.debiais_stream(v_pull);
                        
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

                        self.update_samples(&bags[..]);

                        //println!("View Node{} {:?} ", self.my_id, self.view);
                    }
                    
                    sample(&self.view[..], 1).iter()
                        .for_each(|p| {
                            net.send(*p, Msg::PushRequest);
                            self.update_contact(*p); // if trusted
                        });

                    sample(&self.view[..], 1).iter()
                        .for_each(|p| {
                            net.send(*p, Msg::PullRequest);
                            self.update_contact(*p); // if trusted
                        });

                    if self.is_trusted{
                        self.sketch.to_string(3);
                        let vec = self.sketch.freq_array_string.clone();
                        //println!("vec len {}", vec.len());
                        if self.my_id == self.params.n_trusted + self.params.n_byzantine -1  && DEBUG{
                            self.sketch.print();
                            //println!("layers {:?}", vec);
                        }
                        self.to_conctact.iter()
                        .filter(|x| **x!=self.my_id) // contact only not contacted nodes
                        .map(|x| x)
                        .collect::<Vec<_>>().iter()
                        .for_each(|p| {
                            let layer = 3;
                            
                            for (i, layer) in vec.iter().enumerate() {
                                net.send(**p, Msg::MergeRequest(i, layer.clone())); 
                            }
                        });
                    }
                    net.send(self.my_id, Msg::SelfNotif);
                },
                Msg::PullRequest => {
                    //println!("message PlRq ");
                    net.send(from, Msg::PullReply(self.view.clone()));
                },
                Msg::PullReply(lst) => {
                    //println!("message PlRy ");
                    self.n_received += lst.len();
                    self.n_byzantine_received += lst.iter()
                        .filter(|x| **x < self.params.n_byzantine)
                        .count();
                    self.v_pull.extend(lst);
                    
                   self.sketch.update_freq(lst.clone());
                },
                Msg::PushRequest => {
                    //println!("message PushR ");
                    self.n_received += 1;
                    if from < self.params.n_byzantine {
                        self.n_byzantine_received += 1;
                    }
                    self.v_push.push(from);
                    
                    // create a vector containing only item from 
                    let mut lst = Vec::new();
                    lst.push(from);
                    self.sketch.update_freq(lst.clone());
                },

                Msg::MergeRequest(i, lst) => {
                    //
                    if self.is_trusted{
                        let other_layer = self.sketch.string_to_matrix(*i, lst);
                        self.sketch.merge(*i, other_layer);

                        self.sketch.to_string(*i);
                        net.send(from, Msg::MergeReply(*i, self.sketch.freq_array_string[*i].clone()));
                    }else {
                        println!("message MergeR ");
                    }
                },
                Msg::MergeReply(i, lst) => {
                    //println!("message MergeR ");
                    if self.is_trusted{
                        let other_layer = self.sketch.string_to_matrix(*i, lst);
                        self.sketch.merge(*i, other_layer);
                        
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
            ret
        }
    }
    
}
