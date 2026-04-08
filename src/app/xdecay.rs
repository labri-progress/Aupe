use rand::{rng, Rng};
use rand::{SeedableRng};
use rand::rngs::StdRng;
use cxx::UniquePtr;

use crate::net::{App, PeerRef, Network};
use crate::net::Metrics as NetMetrics;
use crate::util::{hash, sample}; //, sample_nocopy}; //y, write_results};
use crate::util::{print_samples, sample_exclude};

use super::bitmatcher_adaptive::BM;
use crate::app::bitmatcher_adaptive::ffi::BitMatcherAdaptive;
pub use crate::app::aupebmdecay::Init;

use crate::util::SEED2;
use std::sync::{OnceLock, Mutex};

/// Oracle global : accumule les insertions de tous les nœuds corrects et de confiance.
/// Taille = nombre total de nœuds. Initialisé au premier appel à init().
static GLOBAL_OCCURENCE: OnceLock<Mutex<Vec<f64>>> = OnceLock::new();

const DEBUG: bool = false;
pub enum Msg {
    SelfNotif,
    PullRequest,
    PullReply(Vec<PeerRef>),
    PushRequest,
    MergeRequest(UniquePtr<BitMatcherAdaptive>),
    MergeReply(UniquePtr<BitMatcherAdaptive>),
}


pub struct XDecay {
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
    n_byzantine_samples: usize,

    // ---- métriques par groupe : nœuds honnêtes ----
    n_procs_honest: usize,
    /// avgByzN par groupe : proportion de byzantins dans la vue
    n_byz_neighbors_honest: usize,
    /// KL(sketch_norm || oracle_norm) où oracle = stream reçu normalisé
    dkl_honest: f64,
    /// F1 du sketch comme classifieur byz/honest (seuil = fréquence uniforme)
    f1_honest: f64,
    tp_honest: usize,
    /// |bias_sketch - bias_oracle| avec bias = (sumbyz/sumhon) / (n_byz/n_hon)
    bias_factor_err_honest: f64,
    stat_honest: u32,
    occ_honest: f64,

    // ---- métriques par groupe : nœuds de confiance ----
    n_procs_trusted: usize,
    n_byz_neighbors_trusted: usize,
    dkl_trusted: f64,
    f1_trusted: f64,
    tp_trusted: usize,
    bias_factor_err_trusted: f64,
    stat_trusted: u32,
    occ_trusted: f64,
}


impl NetMetrics for Metrics {
    fn empty() -> Self {
        Metrics {
            n_procs: 0,
            n_byzantine_received: 0,
            n_received: 0,
            n_byzantine_neighbors: 0,
            n_byzantine_samples: 0,
            n_procs_honest: 0,
            n_byz_neighbors_honest: 0,
            dkl_honest: 0.0,
            f1_honest: 0.0,
            tp_honest: 0,
            bias_factor_err_honest: 0.0,
            stat_honest: 0,
            occ_honest: 0.0,
            n_procs_trusted: 0,
            n_byz_neighbors_trusted: 0,
            dkl_trusted: 0.0,
            f1_trusted: 0.0,
            tp_trusted: 0,
            bias_factor_err_trusted: 0.0,
            stat_trusted: 0,
            occ_trusted: 0.0,
        }
    }
    fn net_combine(&mut self, other: &Self) {
        self.n_procs += other.n_procs;

        self.n_byzantine_received += other.n_byzantine_received;
        self.n_received += other.n_received;

        self.n_byzantine_neighbors += other.n_byzantine_neighbors;
        self.n_byzantine_samples += other.n_byzantine_samples;

        // groupe honest
        self.n_procs_honest += other.n_procs_honest;
        self.n_byz_neighbors_honest += other.n_byz_neighbors_honest;
        self.dkl_honest += other.dkl_honest;
        self.f1_honest += other.f1_honest;
        self.tp_honest += other.tp_honest;
        self.bias_factor_err_honest += other.bias_factor_err_honest;
        self.stat_honest += other.stat_honest;
        self.occ_honest += other.occ_honest;

        // groupe trusted
        self.n_procs_trusted += other.n_procs_trusted;
        self.n_byz_neighbors_trusted += other.n_byz_neighbors_trusted;
        self.dkl_trusted += other.dkl_trusted;
        self.f1_trusted += other.f1_trusted;
        self.tp_trusted += other.tp_trusted;
        self.bias_factor_err_trusted += other.bias_factor_err_trusted;
        self.stat_trusted += other.stat_trusted;
        self.occ_trusted += other.occ_trusted;
    }
    fn headers() -> Vec<&'static str> { //'
        vec![
            "avgRecv",
            "avgByzRecv",
            "pByzRecv",
            "avgByzN",
            "avgByzSamp",
            // groupe honest
            "h_avgByzN",
            "h_dkl",
            "h_f1",
            "h_tp",
            "h_biasErr",
            "h_division",
            "h_occ",
            // groupe trusted
            "t_avgByzN",
            "t_dkl",
            "t_f1",
            "t_tp",
            "t_biasErr",
            "t_division",
            "t_occ",
        ]
    }
    fn is_empty(&self) -> bool { self.n_procs == 0 }
    fn values(&self) -> Vec<String> {
        let g = |n: usize, d: f64| if n > 0 { d / n as f64 } else { 0.0 };
        let gi = |n: usize, i: usize| if n > 0 { i as f64 / n as f64 } else { 0.0 };
        vec![
            format!("{:.2}", (self.n_received as f32) / (self.n_procs as f32)),
            format!("{:.2}", (self.n_byzantine_received as f32) / (self.n_procs as f32)),
            format!("{:.4}", (self.n_byzantine_received as f32) / (self.n_received as f32)),
            format!("{:.2}", (self.n_byzantine_neighbors as f32) / (self.n_procs as f32)),
            format!("{:.2}", (self.n_byzantine_samples as f32) / (self.n_procs as f32)),
            // groupe honest
            format!("{:.2}", gi(self.n_procs_honest, self.n_byz_neighbors_honest)),
            format!("{:.2}", g(self.n_procs_honest, self.dkl_honest)),
            format!("{:.2}", g(self.n_procs_honest, self.f1_honest)),
            format!("{:.2}", gi(self.n_procs_honest, self.tp_honest)),
            format!("{:.2}", g(self.n_procs_honest, self.bias_factor_err_honest)),
            format!("{}", self.stat_honest),
            format!("{:.2}", g(self.n_procs_honest, self.occ_honest)),
            // groupe trusted
            format!("{:.2}", gi(self.n_procs_trusted, self.n_byz_neighbors_trusted)),
            format!("{:.2}", g(self.n_procs_trusted, self.dkl_trusted)),
            format!("{:.2}", g(self.n_procs_trusted, self.f1_trusted)),
            format!("{:.2}", gi(self.n_procs_trusted, self.tp_trusted)),
            format!("{:.2}", g(self.n_procs_trusted, self.bias_factor_err_trusted)),
            format!("{}", self.stat_trusted),
            format!("{:.2}", g(self.n_procs_trusted, self.occ_trusted)),
        ]
    }
}

type Net<'a> = &'a mut dyn Network<Msg>;

fn kmeans_classify(values: &[f64], max_iters: usize) -> Vec<usize> {
    let n = values.len();
    if n < 2 {
        return vec![0; n];
    }
    let mut rng = StdRng::seed_from_u64(SEED2);
    let i1 = rng.random_range(0..n);
    let mut i2;
    loop {
        i2 = rng.random_range(0..n);
        if i2 != i1 { break; }
    }
    let mut c0 = values[i1];
    let mut c1 = values[i2];
    let mut assignments = vec![0usize; n];

    for _ in 0..max_iters {
        let mut sum0 = 0.0f64; let mut cnt0 = 0usize;
        let mut sum1 = 0.0f64; let mut cnt1 = 0usize;
        for (i, &v) in values.iter().enumerate() {
            if (v - c0).abs() <= (v - c1).abs() {
                assignments[i] = 0; sum0 += v; cnt0 += 1;
            } else {
                assignments[i] = 1; sum1 += v; cnt1 += 1;
            }
        }
        c0 = if cnt0 > 0 { sum0 / cnt0 as f64 } else { c0 };
        c1 = if cnt1 > 0 { sum1 / cnt1 as f64 } else { c1 };
    }
    // class 1 = over-represented (higher frequency cluster)
    if c0 > c1 {
        assignments.iter_mut().for_each(|a| *a = 1 - *a);
    }
    assignments
}

/// Calcule dKL(sketch_norm || oracle_norm), F1 du sketch, et bias_factor relatif.
/// - oracle : comptage brut des IDs reçus ce round (occurence)
/// - probabilities : estimées normalisées du sketch
/// - bias = (sum_byz / sum_hon) / (n_byz / n_hon)
fn compute_sketch_metrics(
    sketch: &mut BM,
    occurence: &[f64],
    n_byzantine: usize,
    n_nodes: usize,
) -> (f64, f64, usize, f64) {
    let total_recv: f64 = occurence.iter().sum();
    if total_recv == 0.0 {
        return (0.0, 0.0, 0, 0.0);
    }

    // Oracle = distribution normalisée du stream reçu
    let oracle: Vec<f64> = occurence.iter().map(|x| x / total_recv).collect();

    // Estimées brutes du sketch pour chaque nœud
    let estimates: Vec<f64> = (0..n_nodes).map(|id| sketch.estimate(&id)).collect();
    let total_est: f64 = estimates.iter().sum();
    let probabilities: Vec<f64> = if total_est > 0.0 {
        estimates.iter().map(|x| x / total_est).collect()
    } else {
        vec![1.0 / n_nodes as f64; n_nodes]
    };

    // dKL(probabilities || oracle)
    let dkl: f64 = probabilities.iter().zip(oracle.iter())
        .map(|(p, q)| if *p > 0.0 && *q > 0.0 { p * (p / q).ln() } else { 0.0 })
        .sum();

    // F1 : k-means classification (2 clusters: over/under represented)
    let classes = kmeans_classify(&probabilities, 20);
    let tp  = (0..n_byzantine).filter(|&i| classes[i] == 1).count();
    let fp  = (n_byzantine..n_nodes).filter(|&i| classes[i] == 1).count();
    let fn_ = (0..n_byzantine).filter(|&i| classes[i] == 0).count();
    let precision = if tp + fp > 0 { tp as f64 / (tp + fp) as f64 } else { 0.0 };
    let recall    = if tp + fn_ > 0 { tp as f64 / (tp + fn_) as f64 } else { 0.0 };
    let f1 = if precision + recall > 0.0 {
        2.0 * precision * recall / (precision + recall)
    } else { 0.0 };

    // bias_factor_err = (bias_sketch - bias_oracle) / bias_oracle (relative)
    // bias = (sum_byz / sum_hon) / (n_byz / n_hon)
    let n_hon = n_nodes - n_byzantine;
    let bias_of = |v: &[f64]| {
        let sb: f64 = v[..n_byzantine].iter().sum();
        let sh: f64 = v[n_byzantine..].iter().sum();
        if sh > 0.0 && n_hon > 0 { (sb / sh) / (n_byzantine as f64 / n_hon as f64) } else { 0.0 }
    };
    let bias_oracle  = bias_of(&oracle);
    let bias_sketch  = bias_of(&probabilities);
    let bias_factor_err = if bias_oracle > 0.0 {
        (bias_sketch - bias_oracle) / bias_oracle
    } else {
        0.0
    };

    (dkl, f1, tp, bias_factor_err)
}


impl XDecay {
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

    /// Sample `n` elements from `from` with probability inversely proportional to occurrence.
    /// Uses Efraimidis-Spirakis weighted reservoir sampling:
    ///   key_i = U_i ^ occur_i
    /// Higher occurrence → larger exponent → key compressed toward 0 → less likely selected.
    /// Elements with zero estimated occurrence get exponent 1.0 (uniform fallback).
    /*fn sample_k(&mut self, from: &[PeerRef], n: usize) -> Vec<PeerRef> {
        if n >= from.len() {
            return from.to_vec();
        }
        // Phase 1: collect occurrences (mutable borrow of self.sketch only)
        let occurs: Vec<f64> = from.iter()
            .map(|peer| self.sketch.estimate(peer).max(1.0))
            .collect();

        // Phase 2: assign keys and sort (mutable borrow of self.rng only)
        let mut keyed: Vec<(f64, PeerRef)> = from.iter().copied()
            .zip(occurs.into_iter())
            .map(|(peer, occur)| {
                let key = self.rng.random::<f64>().powf(occur);
                (key, peer)
            })
            .collect();

        keyed.sort_unstable_by(|a, b| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal));
        keyed.into_iter().take(n).map(|(_, p)| p).collect()
    }*/

    fn sample_k(&mut self, from: &[PeerRef], n: usize) -> Vec<PeerRef> {
        if n == 0 {
            return Vec::new();
        }

        // Deduplicate
        let mut unique: Vec<PeerRef> = from.to_vec();
        unique.sort();
        unique.dedup();

        if n >= unique.len() {
            return unique;
        }

        // Pair each peer with its estimated occurrence (single pass, no intermediate vec)
        let mut keyed: Vec<(f64, PeerRef)> = unique
            .into_iter()
            .map(|peer| (self.sketch.estimate(&peer).max(1.0), peer))
            .collect();

        // Partial sort: find the n peers with smallest occurrence in O(m) average
        // `select_nth_unstable_by` places the nth element in its sorted position,
        // with everything smaller before it — which is exactly what we want.
        keyed.select_nth_unstable_by(n - 1, |a, b| a.0.total_cmp(&b.0));
        keyed.truncate(n);

        keyed.into_iter().map(|(_, p)| p).collect()
    }
}

impl App for XDecay {
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
        // Initialiser le tableau global (idempotent : seul le premier appel alloue)
        GLOBAL_OCCURENCE.get_or_init(|| Mutex::new(vec![0.0f64; init.nodes]));
        //println!("b_byzantine {}",init.n_byzantine);
        self.is_byzantine = id < init.n_byzantine;
        self.is_trusted = self.is_trusted(id); // F to F + T-1

        if !self.is_byzantine || (self.params.attack_start_time > 0){
            let view = net.sample_peers(self.params.view_size);

            self.sample_view = (0..self.params.sample_view_size)
                .map(|_| (self.rng.random_range(0..std::u64::MAX), None)).collect();
            self.update_samples(&view[..]);
            self.view = view;

            self.sketch.update_freq(self.view.clone());
            //self.sketch.debiais_stream(self.view.clone());
            // Comptabiliser la vue initiale dans l'oracle global
            if let Some(occ) = GLOBAL_OCCURENCE.get() {
                let mut occ = occ.lock().unwrap();
                for id in self.view.iter() { occ[*id] += 1.0; }
            }
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
        if self.is_byzantine && net.time() >= self.params.attack_start_time {
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
                    net.send(from, Msg::PullReply(sample(&mut byzantines[..], self.params.view_size, &mut self.rng)));
                },
                _ => (),
            }
        } else {
            match msg {
                Msg::SelfNotif => {
                    let alphav = 1 as usize;
                    let gammav = (self.params.view_size / 3) as usize;
                    let betav = self.params.view_size - alphav - gammav;

                    if !self.v_push.is_empty() && !self.v_pull.is_empty() {
                        let mut v_push = std::mem::replace(&mut self.v_push, Vec::new());
                        let mut v_pull = std::mem::replace(&mut self.v_pull, Vec::new());

                        self.update_samples(&v_push);
                        self.update_samples(&v_pull);

                        v_push = self.sketch.debiais_stream(v_push, &mut self.rng, "push");
                        v_pull = self.sketch.debiais_stream(v_pull, &mut self.rng, "pull");
                        
                        self.push_view = sample(&v_push[..], alphav, &mut self.rng);
                        self.pull_view = sample(&v_pull[..], betav, &mut self.rng);
                        
                        let mut view = self.push_view.clone();
                        view.extend(self.pull_view.clone()); 
                        
                        /*let mut stream = v_push.clone();
                        stream.extend(v_pull.clone());
                        stream = self.sketch.debiais_stream(stream, &mut self.rng);
                        let mut view = sample(&stream[..], 2 * self.params.view_size / 3, &mut self.rng);*/

                        let samples_peer = self.sample_view.iter()
                            .filter(|(_, x)| x.is_some())
                            .map(|(_, x)| x.unwrap())
                            .collect::<Vec<_>>();
                        self.sample_part = sample(&samples_peer[..], gammav, &mut self.rng);
                        
                        view.extend(self.sample_part.clone());

                        view.extend(sample(&self.view[..], self.params.view_size - view.len(), &mut self.rng));
                        self.view = view;

                    }
            
                    if self.is_trusted { //} && net.time()<=100{
                        let view = self.view.clone();
                        self.sample_k(&view, alphav).iter()
                            .for_each(|p| {
                                net.send(*p, Msg::PushRequest);
                                self.update_contact(*p); // if trusted
                            });

                        self.sample_k(&view, betav).iter()
                            .for_each(|p| {
                                net.send(*p, Msg::PullRequest);
                                self.update_contact(*p); // if trusted
                            });

                        let contactlist: Vec<PeerRef> = self.to_conctact.iter()
                            .filter(|x| **x!=self.my_id) // contact only not contacted nodes
                            .copied() //.map(|x| x)
                            .collect::<Vec<_>>();

                        for p in contactlist {
                            net.send(p, Msg::MergeRequest(self.sketch.getdata()));
                        }
                    }else {
                        sample(&self.view[..], alphav, &mut self.rng).iter()
                            .for_each(|p| { net.send(*p, Msg::PushRequest); });

                        sample(&self.view[..], betav, &mut self.rng).iter()
                            .for_each(|p| { net.send(*p, Msg::PullRequest);});
                    }

                    /*if self.my_id == self.params.n_byzantine && net.time()%200==0 { //} && (net.time()==1 || net.time()==200) {//+ self.params.n_trusted -1{
                        let division_count = self.sketch.get_stats().1;
                        println!("Node {} time {}: division_count={}", self.my_id, net.time(), division_count);
                        //self.sketch.print();
                    }*/
                    net.send(self.my_id, Msg::SelfNotif);
                },
                Msg::PullRequest => {
                    //println!("message PlRq ");
                    net.send(from, Msg::PullReply(self.view.clone()));
                },
                Msg::PullReply(lst) => {
                    self.n_received += lst.len();
                    self.n_byzantine_received += lst.iter()
                        .filter(|x| **x < self.params.n_byzantine)
                        .count();
                    if let Some(occ) = GLOBAL_OCCURENCE.get() {
                        let mut occ = occ.lock().unwrap();
                        for id in lst.iter() { occ[*id] += 1.0; }
                    }
                    self.v_pull.extend(lst);
                    self.sketch.update_freq(lst.clone());
                },
                Msg::PushRequest => {
                    self.n_received += 1;
                    if from < self.params.n_byzantine {
                        self.n_byzantine_received += 1;
                    }
                    if let Some(occ) = GLOBAL_OCCURENCE.get() {
                        occ.lock().unwrap()[from] += 1.0;
                    }
                    self.v_push.push(from);
                    let lst = vec![from];
                    self.sketch.update_freq(lst);
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
        if self.is_byzantine && _net.time() >= self.params.attack_start_time {
            Self::Metrics::empty()
        } else {
            let nbn = self.view.iter().filter(|x| **x < self.params.n_byzantine).count();
            let nbs = self.sample_view.iter()
                .filter(|(_, x)| x.is_some())
                .filter(|(_, x)| x.unwrap() < self.params.n_byzantine)
                .count();

            // Métriques sketch vs oracle global (stream agrégé de tous les nœuds corrects+confiance)
            let (dkl, f1, tp, bias_factor_err) = if let Some(occ) = GLOBAL_OCCURENCE.get() {
                let occ_snapshot = occ.lock().unwrap().clone();
                compute_sketch_metrics(
                    &mut self.sketch,
                    &occ_snapshot,
                    self.params.n_byzantine,
                    self.params.nodes,
                )
            } else {
                (0.0, 0.0, 0, 0.0)
            };

            let occ = (0..self.params.nodes)
                .filter(|id| self.sketch.estimate(id) > 0.0)
                .count() as f64 / self.params.nodes as f64;

            let mut ret = Self::Metrics {
                n_procs: 1,
                n_received: self.n_received,
                n_byzantine_received: self.n_byzantine_received,
                n_byzantine_neighbors: nbn,
                n_byzantine_samples: nbs,
                // champs par groupe : remplis selon le type du nœud
                n_procs_honest: 0,
                n_byz_neighbors_honest: 0,
                dkl_honest: 0.0,
                f1_honest: 0.0,
                tp_honest: 0,
                bias_factor_err_honest: 0.0,
                stat_honest: 0,
                occ_honest: 0.0,
                n_procs_trusted: 0,
                n_byz_neighbors_trusted: 0,
                dkl_trusted: 0.0,
                f1_trusted: 0.0,
                tp_trusted: 0,
                bias_factor_err_trusted: 0.0,
                stat_trusted: 0,
                occ_trusted: 0.0,
            };

            if self.is_trusted {
                ret.n_procs_trusted = 1;
                ret.n_byz_neighbors_trusted = nbn;
                ret.dkl_trusted = dkl;
                ret.f1_trusted = f1;
                ret.tp_trusted = tp;
                ret.bias_factor_err_trusted = bias_factor_err;
                ret.stat_trusted = self.sketch.get_stats().1;
                ret.occ_trusted = occ;
            } else {
                ret.n_procs_honest = 1;
                ret.n_byz_neighbors_honest = nbn;
                ret.dkl_honest = dkl;
                ret.f1_honest = f1;
                ret.tp_honest = tp;
                ret.bias_factor_err_honest = bias_factor_err;
                ret.stat_honest = self.sketch.get_stats().1;
                ret.occ_honest = occ;
            }

            self.n_received = 0;
            self.n_byzantine_received = 0;

            ret
        }
    }
    
}
