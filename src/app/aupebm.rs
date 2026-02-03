use rand::{rng, Rng};
use rand::{SeedableRng};
use rand::rngs::StdRng;
use cxx::UniquePtr;
use structopt::StructOpt;

use crate::net::{App, PeerRef, Network};
use crate::net::Metrics as NetMetrics;
use crate::util::{either_or_if_both, hash, sample, sample_nocopy}; //y, write_results};
use crate::util::{print_samples, sample_exclude};

use super::bitmatcher::BM;
use crate::app::bitmatcher::ffi::BitMatcher;

use crate::util::SEED2;
const DEBUG: bool = false;
pub enum Msg {
    SelfNotif,
    PullRequest,
    PullReply(Vec<PeerRef>),
    PushRequest,
    MergeRequest(UniquePtr<BitMatcher>),
    MergeReply(UniquePtr<BitMatcher>),
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

    /// Number of SGX nodes
    #[structopt(short = "x", long = "trusted-nodes", default_value = "0")]
    pub n_trusted: usize,

    /// How many sup merges should be used
    #[structopt(short = "p", long = "nb_merges", default_value = "0")]
    pub nb_merge: usize,

    //BitMatcher
    #[structopt(short = "c", long = "n_bucket", default_value = "0")]
    pub n_bucket: u64,

    #[structopt(short = "y", long = "budget", default_value = "1")]
    pub space: u64,
}

pub struct AupeBM {
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

    sketch: BM,
    to_conctact: Vec<PeerRef>,
    oldest: PeerRef,
    rng: StdRng,
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

    stat: u32,

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
            stat: 0,
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

        self.stat += other.stat;
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
            "blocked_count",
        ]
    }
    fn values(&self) -> Vec<String> {
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
            format!("{}", self.stat),
        ]
    }
}

type Net<'a> = &'a mut dyn Network<Msg>;


impl AupeBM {
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
        }
    }

    fn is_trusted(&self, id:PeerRef) -> bool {
        return id >= self.params.n_byzantine && id < self.params.n_byzantine + self.params.n_trusted;
    }
}

impl App for AupeBM {
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

            sketch: BM::new().into(),
            to_conctact: Vec::new(),
            oldest: 0,
            rng: StdRng::seed_from_u64(SEED2),
        }
    }
    
    fn init(&mut self, id: PeerRef, net: Net, init: &Self::Init) {
        self.my_id = id;
        self.params = init.clone();

        // Init preallocated vectors
        self.sketch.init(self.params.nodes, self.params.clone());
        self.rng = StdRng::seed_from_u64(SEED2 + id as u64);
        //println!("b_byzantine {}",init.n_byzantine);
        self.is_byzantine = id < init.n_byzantine;
        self.is_trusted = self.is_trusted(id); // F to F + T-1

        if !self.is_byzantine {
            let view = net.sample_peers(self.params.view_size);

            self.sample_view = (0..self.params.sample_view_size)
                .map(|_| (self.rng.random_range(0..std::u64::MAX), None)).collect();
            self.update_samples(&view[..]);
            self.view = view;

            self.sketch.update_freq(self.view.clone());
            //self.sketch.debiais_stream(self.view.clone());
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
                sample_exclude::<usize, _>( trusted_nodes, &mut self.to_conctact, 
                    missing_len , self.my_id, &mut self.rng);
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
                    net.send(from, Msg::PullReply(sample_nocopy(&mut byzantines[..], self.params.view_size, &mut self.rng)));
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

                        
                        self.update_samples(&v_push);
                        self.update_samples(&v_pull);

                        v_push = self.sketch.debiais_stream(v_push, &mut self.rng);
                        v_pull = self.sketch.debiais_stream(v_pull, &mut self.rng);
                        
                        self.push_view = sample(&v_push[..], self.params.view_size / 3, &mut self.rng);
                        self.pull_view = sample(&v_pull[..], self.params.view_size / 3, &mut self.rng);
                        
                        let mut view = self.push_view.clone();
                        view.extend(self.pull_view.clone());

                        let samples_peer = self.sample_view.iter()
                            .filter(|(_, x)| x.is_some())
                            .map(|(_, x)| x.unwrap())
                            .collect::<Vec<_>>();
                        self.sample_part = sample(&samples_peer[..], self.params.view_size - view.len(), &mut self.rng);
                        
                        view.extend(self.sample_part.clone());

                        view.extend(sample(&self.view[..], self.params.view_size - view.len(), &mut self.rng));
                        self.view = view;

                    }
                    
                    sample(&self.view[..], 1, &mut self.rng).iter()
                        .for_each(|p| {
                            net.send(*p, Msg::PushRequest);
                            self.update_contact(*p); // if trusted
                        });

                    sample(&self.view[..], 1, &mut self.rng).iter()
                        .for_each(|p| {
                            net.send(*p, Msg::PullRequest);
                            self.update_contact(*p); // if trusted
                        });

                    if self.is_trusted{
                        let contactlist: Vec<PeerRef> = self.to_conctact.iter()
                            .filter(|x| **x!=self.my_id) // contact only not contacted nodes
                            .copied() //.map(|x| x)
                            .collect::<Vec<_>>();

                        for p in contactlist {
                            net.send(p, Msg::MergeRequest(self.sketch.getdata()));
                        }
                    }
                    
                    /*if self.my_id == self.params.n_byzantine && net.time() %200==0 { //} && (net.time()==1 || net.time()==200) {//+ self.params.n_trusted -1{
                        let blocked_count = self.sketch.get_stats().0;
                        println!("Node {} time {}: blocked_count={}", self.my_id, net.time(), blocked_count);
                        //self.sketch.print();
                    }*/
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

                Msg::MergeRequest(other_sketch) => {
                    //println!("node {} receive MergeRequest from {}", self.my_id, from);
                    if self.is_trusted{
                        /* 1. Receive sketch */
                        /* 2. Send yours */
                        net.send(from, Msg::MergeReply(self.sketch.getdata()));
                        /* 3. Merge */
                        self.sketch.merge(other_sketch); 

                        /* 1. Receive sketch */
                        /* 2. Merge */
                        //self.sketch.merge(other_sketch);
                        /* 2. Send results */
                        //net.send(from, Msg::MergeReply(self.sketch.getdata()));
                        
                    }else {
                        println!("message MergeR ");
                    }
                },
                Msg::MergeReply(other_sketch) => {
                    //println!("node {} receive MergeReply from {}", self.my_id, from);
                    if self.is_trusted{
                        self.sketch.merge(other_sketch);
                        
                        /* update my sketch */
                        //self.sketch.copy(other_sketch);
                        
                    }
                },
            }
        }
    }

    
    fn metrics(&mut self, _net: Net) -> Self::Metrics {
        if self.is_byzantine {
            Self::Metrics::empty()
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
                stat: self.sketch.get_stats().0,
            };
            self.n_received = 0;
            self.n_byzantine_received = 0;
          
            ret
        }
    }
    
}
