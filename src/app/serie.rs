use rand::{thread_rng, Rng};
use structopt::StructOpt;

use crate::net::{App, PeerRef, Network};
use crate::net::Metrics as NetMetrics;
use crate::util::{either_or_if_both, get_matrix_dimensions, hash, print_samples, sample, sample_exclude, sample_nocopy, string_to_matrix};
use crate::rps::RPS;
use crate::graph::ByzConnGraph;

use super::cms::CountMinSketch;

const DEBUG: bool = false;
const REPLACEMENT_FREQUENCY: Option<u64> =Some(1);
const REPLACEMENT_COUNT: usize=0;

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

    /// Number of SGX nodes
    #[structopt(short = "x", long = "trusted-nodes", default_value = "0")]
    pub n_trusted: usize,
 
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
    
    /// How many sup merges should be used
    #[structopt(short = "p", long = "nb_merges", default_value = "0")]
    pub nb_merge: usize,

    /// number_of_hash_function
    #[structopt(short = "d", long = "number_of_hash_function", default_value = "2")]
    pub depth: usize,

    /// Number_of_discrete_values
    #[structopt(short = "w", long = "number_of_discrete_values", default_value = "5")]
    pub width: usize,

    /// Number of CMS in serie
    #[structopt(short = "r", long = "number_of_cms_in_serie", default_value = "0")]
    pub serie: usize,
} 

impl Init {
    /// Validates the parameters of the `Init` struct.
    /// Exits the program with an error message if the parameters are invalid.
    pub fn validate(&self) {
        if self.serie < 2 {
            eprintln!("Error: The number of cms in serie must be greater than one.");
            std::process::exit(1);
        }
        if self.nodes == 0 {
            eprintln!("Error: The number of nodes must be greater than zero.");
            std::process::exit(1);
        }
        if self.view_size >= self.nodes || self.memory_size >= self.nodes {
            eprintln!(
                "Error: The view size/the sample memory size ({}/{}) cannot exceed the total number of nodes ({}).",
                self.view_size, self.memory_size, self.nodes
            );
            std::process::exit(1);
        }
        if self.view_size != self.sample_view_size {
            eprintln!(
                "Error: The sample_view size ({}) must be equal to the view size ({}).",
                self.sample_view_size, self.view_size
            );
            std::process::exit(1);
        }
        if self.n_trusted >= self.nodes || self.n_byzantine > self.nodes{
            eprintln!(
                "Error: The number of trusted/byzantine nodes ({}/{}) cannot exceed the total number of nodes ({}).",
                self.n_trusted, self.n_byzantine, self.nodes
            );
            std::process::exit(1);
        }

        if self.n_trusted == 0 && self.nb_merge != 0 {
            eprintln!("Error: The number of trusted nodes must be non null OR You have to unset the use of nb_merge");
            std::process::exit(1);
        }

        if self.n_trusted != 0 && (self.nb_merge == 0 || self.n_trusted == self.nb_merge){
            eprintln!("Error: Set the number of merge {} for the {} trusted nodes", self.nb_merge, self.n_trusted);
            std::process::exit(1);
        }

        /* if self.depth >= self.nodes || self.width >= self.nodes || self.depth > self.width {
            eprintln!("Error: The CMS ({}x{}) is too big. The total number of nodes is {}", 
                self.depth, self.width,self.nodes);
            std::process::exit(1);
        } */
        
        let dim_r_min= 2.0*(self.serie as f64).sqrt();

        if (self.depth as f64) < dim_r_min || (self.width as f64) < dim_r_min || self.memory_size  < 2 * self.serie {
            eprintln!("Error: The CMS ({}x{})-{} is too small. The minimum dimension is {}-{} with {} series", 
                self.depth, self.width, self.memory_size, dim_r_min, 2 * self.serie, self.serie);
            std::process::exit(1);
        }

        if DEBUG{
            println!("Parameters are valid: {:?}", self);
        }
        
    }
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

pub struct Serie {
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

    cms: Vec<CountMinSketch>, // r cms of size d*w

    omniscient_freq_array_string: String,
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


impl Serie {
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

    fn debiais_stream_with_kfree(&mut self, inputstream: Vec<usize>) -> Vec<usize> {
        
        if self.my_id == self.params.n_trusted + self.params.n_byzantine -1  && DEBUG{
            println!("*** CLEAN ***");
        }
        let mut outputstream = Vec::new();
        let mut shuffled_input = inputstream.to_vec();
        
        for cms in &mut self.cms {
            outputstream = Vec::new();
            cms.debiais_stream_with_kfree(shuffled_input.clone());
            
            shuffled_input = outputstream.to_vec();
            
        }
        outputstream
    }


    fn update_contact(&mut self, item: PeerRef) {
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
    }

    fn is_trusted(&self, id:PeerRef) -> bool {
        return id >= self.params.n_byzantine && id < self.params.n_byzantine + self.params.n_trusted;
    }

    fn show_role(&self) {
        let role;
        if self.is_byzantine{
            role = "byzantine";
        } else if self.is_trusted {
            role = "trusted";
        } else {
            role = "correct";
        }
        println!("Node {} is {}", self.my_id, role);
    }
}

impl App for Serie {
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
            cms: Vec::new(),

            omniscient_freq_array_string: String::new(),
            to_conctact: Vec::new(),
            oldest: 0,
        }
    }
    
    fn init(&mut self, id: PeerRef, net: Net, init: &Self::Init) {
        self.my_id = id;
        init.validate();
        self.params = init.clone();
    
        // Init preallocated vectors
        //self.omniscient_freq_array = vec![-1.0; self.params.nodes];
        
        let cms_depth = (init.depth as f64 / (init.serie as f64).sqrt()) as usize;
        let cms_width = (init.width as f64 / (init.serie as f64).sqrt()).ceil() as usize;
        //self.sample_memory_size = (init.memory_size as f64 / init.serie as f64) as usize;
        // ci = 1/r (s1 s2 + c - r s1i s2i)
        let sample_memory_size = ((init.depth * init.width + init.memory_size - 
            init.serie* cms_depth * cms_width) as f64 / init.serie as f64) as usize;
        /* print!("-------element of A(r) have dimensions {}x{}-{}", 
            cms_depth, cms_width, sample_memory_size); */

        (0..self.params.serie).for_each(|_| {
            self.cms.push(CountMinSketch::new(cms_width, cms_depth, sample_memory_size));
        });
        
        self.is_byzantine = id < init.n_byzantine; // 0 to F-1
        self.is_trusted = self.is_trusted(id); // F to F + T-1
        // the rest is correct node
        if false {
            self.show_role();
        }
        
        if !self.is_byzantine {
            let view = net.sample_peers(self.params.view_size);

            let mut rng = thread_rng();
            self.sample_view = (0..self.params.sample_view_size)
                .map(|_| (rng.gen_range(0, std::u64::MAX), None)).collect();
            self.update_samples(&view[..]);
            self.view = view;
           
            if self.my_id == self.params.n_trusted + self.params.n_byzantine -1  && DEBUG{
                println!("Init VIEW {:?}", self.view);
            }
            self.debiais_stream_with_kfree(self.view.clone());
            
        }
        // init to_ccontact list
        if self.is_trusted && self.params.nb_merge != 0{
            let trusted_nodes = (self.params.n_byzantine..self.params.n_trusted+self.params.n_byzantine).collect::<Vec<_>>();
            if self.my_id == self.params.n_trusted + self.params.n_byzantine -1  && DEBUG{
                for (i,cms) in self.cms.iter().enumerate() {
                    print!("-------CMS {} of dimensions {:?}-{}", i, cms.dim(), cms.sample_memory_size);
                    //cms.print();
                } 
            }

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
        } else if self.is_trusted{
            match msg {
                Msg::SelfNotif => {
                    if let Some(rf) = REPLACEMENT_FREQUENCY {
                        if (self.my_id as u64 + net.time()) % rf == 0 {
                            let mut rng = thread_rng();
                            let view = self.view.clone();
                            let sample_view = self.sample_view.iter()
                                .filter(|(_, x)| x.is_some())
                                .map(|(_, x)| x.unwrap())
                                .collect::<Vec<_>>();
                            for k in 0..REPLACEMENT_COUNT {
                                let i_replace = ((net.time() / rf) as usize * REPLACEMENT_COUNT + k) % self.sample_view.len();
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
                    if self.my_id == self.params.n_trusted + self.params.n_byzantine -1 && DEBUG{
                        println!("vpush({:?}) vpull({:?})",self.v_push, self.v_pull);
                    }
                    
                    if !self.v_push.is_empty() && !self.v_pull.is_empty() {
                        
                        if self.my_id == self.params.n_trusted + self.params.n_byzantine -1 && DEBUG{
                            //println!("vpush{:?} vpull{:?}",self.v_push, self.v_pull);
                            println!("vpush({}) vpull({})", self.v_push.len(), self.v_pull.len());
                        }
                        let mut v_push = std::mem::replace(&mut self.v_push, Vec::new());
                        let mut v_pull = std::mem::replace(&mut self.v_pull, Vec::new());
                        
                        self.update_samples(&v_push);
                        self.update_samples(&v_pull);

                        v_push = self.debiais_stream_with_kfree(v_push);
                        v_pull = self.debiais_stream_with_kfree(v_pull);
                        
                        if self.my_id == self.params.n_trusted + self.params.n_byzantine -1 && DEBUG{
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
                    
                    if self.my_id == self.params.n_trusted + self.params.n_byzantine -1 && DEBUG{
                        println!("View Node{} {:?} : push {:?} pull {:?} sample {:?}", 
                            self.my_id, self.view, self.push_view, self.pull_view, self.sample_part);
                        print_samples(&mut self.sample_view);
                    }

                    if self.my_id == self.params.n_trusted + self.params.n_byzantine -1 && DEBUG{
                        println!("node { }", self.my_id);
                        for (i,cms) in self.cms.iter().enumerate() {
                            print!("-------CMS {}", i);
                            //cms.print();
                            //println!("dimensions of the cms {:?}", cms.dim());
                            println!("    Sample memory{} : {:?} and minvalue {}", i,
                                cms.omniscient_memory, cms.min_value);
                        }
                    }
                    
                    sample(&self.view[..], 1).iter()
                        .for_each(|p| {
                            net.send(*p, Msg::PushRequest);
                            if self.params.nb_merge != 0{
                                self.update_contact(*p);
                            }
                        });

                    sample(&self.view[..], 1).iter()
                        .for_each(|p| {
                            net.send(*p, Msg::PullRequest);
                            if self.params.nb_merge != 0 {
                                self.update_contact(*p);
                            }
                        });
                        
                    if DEBUG && self.params.nb_merge != 0 &&
                        self.my_id == self.params.n_trusted + self.params.n_byzantine -1 {
                        println!("Node { } : to_contacted({:?}) M={} oldest=Node{}",self.my_id,
                            self.to_conctact, self.params.nb_merge, self.oldest);
                    }

                    for (i,cms) in self.cms.iter().enumerate() {
                        self.omniscient_freq_array_string = cms.matrix_to_string();

                        self.to_conctact.iter()
                            .filter(|x| **x!=self.my_id) // contact only not contacted nodes
                            .map(|x| x)
                            .collect::<Vec<_>>().iter()
                            .for_each(|p| {
                                net.send(**p, Msg::MergeRequest(i, self.omniscient_freq_array_string.to_string())) 
                            });
                    }
                        net.send(self.my_id, Msg::SelfNotif); 
                },
                Msg::PullRequest => {
                    net.send(from, Msg::PullReply(self.view.clone()));
                },
                Msg::PullReply(lst) => {
                    self.n_received += lst.len();
                    self.n_byzantine_received += lst.iter()
                        .filter(|x| **x < self.params.n_byzantine)
                        .count();
                    self.v_pull.extend(lst);
                },
                Msg::PushRequest => {
                    self.n_received += 1;
                    if from < self.params.n_byzantine {
                        self.n_byzantine_received += 1;
                    }
                    self.v_push.push(from);
                },
                Msg::MergeRequest(cmsid,lst) => {
                    net.send(from, Msg::MergeReply(*cmsid, 
                            self.cms[*cmsid].matrix_to_string())); //send its struct before merging
                   
                    let other_cms = string_to_matrix(lst);
                    
                    if get_matrix_dimensions(&other_cms) == (self.cms[*cmsid].depth, self.cms[*cmsid].width) && 
                        *cmsid < self.params.serie{
                        if self.my_id == self.params.n_trusted + self.params.n_byzantine -1 && DEBUG{
                            self.cms[*cmsid].print();
                            print!("+++ MERGE({}) ", cmsid);
                            println!(" with {} +++", lst);
                        }
                        self.cms[*cmsid].merge_cms(other_cms);
                    }else{
                        println!("MergeRequest: Error parsing string {:?} ({},{})", 
                        get_matrix_dimensions(&other_cms), self.cms[*cmsid].depth, self.cms[*cmsid].width);
                    }
                },
                Msg::MergeReply(cmsid, lst) => {
                    if self.my_id == self.params.n_trusted + self.params.n_byzantine -1 && DEBUG{
                        //println!("message MergeRy from {} :{:?} ", from.to_string(), lst);
                    }
                    let other_cms = string_to_matrix(lst);
                    
                    if get_matrix_dimensions(&other_cms) == (self.cms[*cmsid].depth, self.cms[*cmsid].width) && 
                        *cmsid < self.params.serie{
                        if self.my_id == self.params.n_trusted + self.params.n_byzantine -1 && DEBUG{
                            self.cms[*cmsid].print();
                            print!("+++ MERGE({}) ", cmsid);
                            println!(" with {} +++", lst);
                        }
                        self.cms[*cmsid].merge_cms(other_cms);
                    }else{
                        println!("MergeReply: Error parsing string {:?} ({},{})", 
                        get_matrix_dimensions(&other_cms), self.cms[*cmsid].depth, self.cms[*cmsid].width);
                    }
                },
            }
        } else {
            match msg {
                Msg::SelfNotif => {
                    if let Some(rf) = REPLACEMENT_FREQUENCY {
                        if (self.my_id as u64 + net.time()) % rf == 0 {
                            let mut rng = thread_rng();
                            let view = self.view.clone();
                            let sample_view = self.sample_view.iter()
                                .filter(|(_, x)| x.is_some())
                                .map(|(_, x)| x.unwrap())
                                .collect::<Vec<_>>();
                            for k in 0..REPLACEMENT_COUNT {
                                let i_replace = ((net.time() / rf) as usize * REPLACEMENT_COUNT + k) % self.sample_view.len();
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
                        //println!("vpush({:?}) vpull({:?})",self.v_push, self.v_pull);
                    }

                    if !self.v_push.is_empty() && !self.v_pull.is_empty() {
                        
                        if self.my_id == self.params.nodes-1 && DEBUG{
                            //println!("vpush({}) vpull({})", self.v_push.len(), self.v_pull.len());
                        }
                        let mut v_push = std::mem::replace(&mut self.v_push, Vec::new());
                        let mut v_pull = std::mem::replace(&mut self.v_pull, Vec::new());
                        
                        self.update_samples(&v_push);
                        self.update_samples(&v_pull);

                        v_push = self.debiais_stream_with_kfree(v_push);
                        v_pull = self.debiais_stream_with_kfree(v_pull);
                        
                        if self.my_id == self.params.nodes-1 && DEBUG{
                            //eprintln!("AFTER debiasing vpush{:?} vpull{:?}",v_push, v_pull);
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
                    
                    sample(&self.view[..], 1).iter()
                        .for_each(|p| {
                            net.send(*p, Msg::PushRequest)
                        });

                    sample(&self.view[..], 1).iter()
                        .for_each(|p| {
                            net.send(*p, Msg::PullRequest)
                        });

                    net.send(self.my_id, Msg::SelfNotif);
                },
                Msg::PullRequest => {
                    net.send(from, Msg::PullReply(self.view.clone()));
                },
                Msg::PullReply(lst) => {
                    if self.my_id == self.params.nodes-1 && DEBUG{
                        /* eprintln!("message PlRy from {} : {:?}", 
                        from.to_string(), lst); */
                    }
                    self.n_received += lst.len();
                    self.n_byzantine_received += lst.iter()
                        .filter(|x| **x < self.params.n_byzantine)
                        .count();
                    self.v_pull.extend(lst);
                    
                },
                Msg::PushRequest => {
                    if self.my_id == self.params.nodes-1 && DEBUG{
                        //eprintln!("message PushR from {} ", from.to_string());
                    }
                    self.n_received += 1;
                    if from < self.params.n_byzantine {
                        self.n_byzantine_received += 1;
                    }
                    self.v_push.push(from);
               
                },
                Msg::MergeRequest(_cmsid, _lst) => {
                    //println!("NO MERGERq ");    
                },
                Msg::MergeReply(_cmsid, _lst) => {
                    //eprintln!("NO MERGERply"); 
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
          
            ret
        }
    }
}

impl RPS for Serie {
    fn get_samples(&mut self) -> Vec<PeerRef> {
        std::mem::replace(&mut self.out_samples, Vec::new())
    }
    fn clear_samples(&mut self) {
        self.out_samples.clear();
    }
}
