use rand::{rng, Rng};
use rand::rngs::StdRng;
use rand::SeedableRng; 
use rand::prelude::SliceRandom;

use structopt::StructOpt;

use super::aupebmdecay::Init;

use cxx::UniquePtr;
use cxx::CxxString;
use std::pin::Pin;

use crate::util::SEED2;

#[cxx::bridge(namespace = "org::blobstore")]
pub mod ffi {
    unsafe extern "C++" {
        include!("aupe/include/bitmatcher_adaptive.h");

        type BitMatcherAdaptive;

        fn clone(self: &BitMatcherAdaptive)-> UniquePtr<BitMatcherAdaptive>;
        fn new_BitMatcherAdaptive(bucket: u64) -> UniquePtr<BitMatcherAdaptive>;
        fn Insert(self: Pin<&mut BitMatcherAdaptive>, key: &CxxString, key_len: i16); //key: &str,key_len: u16);
        fn Query(self: Pin<&mut BitMatcherAdaptive>, key: &CxxString, key_len: i16) -> f64;
        fn QueryAvgBucket(self: Pin<&mut BitMatcherAdaptive>, key: &CxxString, key_len: i16) -> f64;
        fn QueryMaxBucket(self: Pin<&mut BitMatcherAdaptive>, key: &CxxString, key_len: i16) -> f64;
        fn print_buckets(self: &BitMatcherAdaptive);
        fn merge(self: Pin<&mut BitMatcherAdaptive>, other: &BitMatcherAdaptive);
        fn get_blocked_count(self: &BitMatcherAdaptive) -> u32;
        fn get_division_count(self: &BitMatcherAdaptive) -> u32;
        fn get_min_count(self: &BitMatcherAdaptive) -> u64;
        fn get_max_count(self: &BitMatcherAdaptive) -> u64;
        // Adaptive strategy methods
        fn decay(self: Pin<&mut BitMatcherAdaptive>);
        fn get_item_slot_key(self: Pin<&mut BitMatcherAdaptive>, key: &CxxString, key_len: i16) -> u64;
        fn GetCount(self: Pin<&mut BitMatcherAdaptive>, key: &CxxString, key_len: i16) -> i64;
    }
}
unsafe impl Send for ffi::BitMatcherAdaptive {}
unsafe impl Sync for ffi::BitMatcherAdaptive {}
impl Clone for BM {
    fn clone(&self) -> Self {
        BM {
            params: self.params.clone(),
            matrix: self.matrix.as_ref().unwrap().clone(), 
            key_len: self.key_len,
            omniscient_memory_push: self.omniscient_memory_push.clone(),
            omniscient_memory_pull: self.omniscient_memory_pull.clone(),
        }
    }
}

use crate::app::bitmatcher_adaptive::ffi::BitMatcherAdaptive;


use cxx::let_cxx_string;

pub struct BM {
    pub params: Init,
    pub matrix: UniquePtr<BitMatcherAdaptive>,
    pub key_len: usize,
    pub omniscient_memory_push: Vec<usize>,
    pub omniscient_memory_pull: Vec<usize>,
}

fn count_digits(n: usize) -> usize {
    n.to_string().chars().count()
}

impl BM {

    pub fn insert(&mut self, item: &usize) { 

        let item_str = format!("{:0>width$}", item, width = self.key_len);
        let_cxx_string!(key = item_str);
        self.matrix.as_mut().unwrap().Insert(&key, self.key_len as i16)
    }
    
    /// Estime la fréquence d'un élément
    pub fn estimate(&mut self, item: &usize) -> f64 {

        let item_str = format!("{:0>width$}", item, width = self.key_len);
        let_cxx_string!(key = item_str);
        let result = self.matrix.as_mut().unwrap().Query(&key, self.key_len as i16);
        result
    }

    pub fn new() -> Self {
        Self {
            params: Init::default(),
            matrix: ffi::new_BitMatcherAdaptive(0),
            key_len: 4,
            omniscient_memory_push: Vec::new(),
            omniscient_memory_pull: Vec::new(),
        }
    }
    
    pub fn print(&self) {
        //println!("BM of 2 arrays, each of {:?} buckets of size 64 bits", self.params.n_bucket); 
        self.matrix.print_buckets();
         println!("Getting stats bm: {:?}", self.get_stats());
    }

    pub fn getparams(&mut self, init: Init) {
        self.params = init;
        if self.params.n_bucket == 0 {
            self.params.n_bucket = (self.params.space * 1024.0 / 8.0 / 2.0) as u64;
        }
    }

    pub fn init(&mut self, nodes: usize, init: Init) {
    
        self.getparams(init.clone());
        self.key_len = count_digits(nodes -1);
        self.matrix = ffi::new_BitMatcherAdaptive(self.params.n_bucket);
        
    }

    pub fn get_stats(&self) -> (u32, u32) {
        (self.matrix.get_blocked_count(), self.matrix.get_division_count())
    }

    pub fn update_freq(&mut self, mut items: Vec<usize>) {

        for item in items {
            self.insert(&item);
        }
    }

    pub fn getdata(&mut self) -> UniquePtr<BitMatcherAdaptive>{
        return self.matrix.as_ref().unwrap().clone()
    }

    pub fn copy(&mut self, other: &BitMatcherAdaptive) {
        self.matrix = other.clone();
    }

    pub fn merge(&mut self, other: &BitMatcherAdaptive) {
        //self.matrix.as_mut().unwrap().merge(&other); 
        self.matrix.as_mut().unwrap().merge(other);
    }
    

    /// Retourne le compteur stocké physiquement pour `item`, ou -1 s'il est absent.
    pub fn get_count_of(&mut self, item: &usize) -> i64 {
        let item_str = format!("{:0>width$}", item, width = self.key_len);
        let_cxx_string!(key = item_str);
        self.matrix.as_mut().unwrap().GetCount(&key, self.key_len as i16)
    }

    pub fn slot_key_of(&mut self, item: &usize) -> u64 {
        let item_str = format!("{:0>width$}", item, width = self.key_len);
        let_cxx_string!(key = item_str);
        self.matrix.as_mut().unwrap().get_item_slot_key(&key, self.key_len as i16)
    }

    pub fn debiais_stream(&mut self, inputstream: Vec<usize>, rng: &mut StdRng, from: &str) -> Vec<usize> {
        // Use the minimum non-zero count currently stored in the sketch as the
        // reference for the acceptance probability.  This is scale-invariant: after a
        // global decay (all counts halved) both ref_min and item counts halve, so the
        // ratio ref_min/occur is preserved.  Unlike the historical running min_value,
        // it always reflects the current sketch state after merges and decays.
        let ref_min = self.matrix.as_ref().unwrap().get_min_count() as f64;

        let estimates: Vec<f64> = inputstream.iter().map(|e| self.estimate(e)).collect();

        let mut outputstream = Vec::new();

        let memory = if from == "push" {
            &mut self.omniscient_memory_push
        } else {
            &mut self.omniscient_memory_pull
        };

        for (element, &occur) in inputstream.iter().zip(estimates.iter()) {
            /* if occur < ref_min {
                panic!("Error: estimate {} is less than ref_min {}", occur, ref_min);
            } */
            if memory.len() < self.params.memory_size {
                if !memory.contains(element) {
                    memory.push(*element);
                }
            } else {
                let prob = if occur == 0.0 { 1.0 } else { (ref_min / occur).min(1.0) };
                let random_float: f64 = rng.random();
                if random_float < prob && !memory.contains(element) {
                    let i = rng.random_range(0..self.params.memory_size);
                    memory[i] = *element;
                }
            }
            if !memory.is_empty() {
                let i = rng.random_range(0..memory.len());
                outputstream.push(memory[i]);
            }
        }

        outputstream
    }

    /// Requête v3 : si présent et bucket plein -> max du sketch,
    /// si présent et bucket non plein -> compteur individuel de l'élément,
    /// sinon (absent) -> comportement original (0 ou min du bucket).
    pub fn estimate_v3(&mut self, item: &usize) -> f64 {
        let item_str = format!("{:0>width$}", item, width = self.key_len);
        let_cxx_string!(key = item_str);
        self.matrix.as_mut().unwrap().QueryMaxBucket(&key, self.key_len as i16)
    }

    /// Debiasing v3 : même logique que debiais_stream original (ref_min / occur),
    /// mais l'occurrence est obtenue via QueryAvgBucket au lieu de Query.
    pub fn debiais_stream_v3(&mut self, inputstream: Vec<usize>, rng: &mut StdRng, from: &str) -> Vec<usize> {
        let ref_min = self.matrix.as_ref().unwrap().get_min_count() as f64;

        let estimates: Vec<f64> = inputstream.iter().map(|e| self.estimate_v3(e)).collect();

        let mut outputstream = Vec::new();

        let memory = if from == "push" {
            &mut self.omniscient_memory_push
        } else {
            &mut self.omniscient_memory_pull
        };

        for (element, &occur) in inputstream.iter().zip(estimates.iter()) {
            if memory.len() < self.params.memory_size {
                if !memory.contains(element) {
                    memory.push(*element);
                }
            } else {
                let prob = if occur == 0.0 { 1.0 } else { (ref_min / occur).min(1.0) };
                let random_float: f64 = rng.random();
                if random_float < prob && !memory.contains(element) {
                    let i = rng.random_range(0..self.params.memory_size);
                    memory[i] = *element;
                }
            }
            if !memory.is_empty() {
                let i = rng.random_range(0..memory.len());
                outputstream.push(memory[i]);
            }
        }

        outputstream
    }

    /// Debiasing conditionné par la présence physique de la clé dans le sketch.
    ///
    /// Pour chaque élément du stream :
    ///   - clé ABSENTE du sketch  (GetCount == -1) → prob = 1.0         (toujours garder)
    ///   - clé PRÉSENTE du sketch (GetCount >= 0)  → prob = min_count / max_count
    ///
    /// `min_count` et `max_count` sont les compteurs min/max globaux du sketch
    /// (calculés une seule fois par appel).  Tous les éléments présents reçoivent
    /// la même probabilité d'acceptation, qui décroît à mesure que l'écart entre
    /// éléments rares et fréquents (byzantins) se creuse.
    pub fn debiais_stream_v2(&mut self, inputstream: Vec<usize>, rng: &mut StdRng, from: &str) -> Vec<usize> {
        let ref_min = self.matrix.as_ref().unwrap().get_min_count() as f64;
        let ref_max = self.matrix.as_ref().unwrap().get_max_count() as f64;
        let prob_present = if ref_max > 0.0 { (ref_min / ref_max).min(1.0) } else { 1.0 };

        //let prob_present = 1.0/1023.0;

        // Pré-calcul des présences (emprunte matrix, libère avant de toucher memory)
        let counts: Vec<i64> = inputstream.iter().map(|e| self.get_count_of(e)).collect();

        let memory = if from == "push" {
            &mut self.omniscient_memory_push
        } else {
            &mut self.omniscient_memory_pull
        };

        let mut outputstream = Vec::new();

        for (element, &stored) in inputstream.iter().zip(counts.iter()) {
            let prob = if stored < 0 { 1.0 } else { prob_present };

            if memory.len() < self.params.memory_size {
                if !memory.contains(element) {
                    memory.push(*element);
                }
            } else {
                let random_float: f64 = rng.random();
                if random_float < prob && !memory.contains(element) {
                    let i = rng.random_range(0..self.params.memory_size);
                    memory[i] = *element;
                }
            }
            if !memory.is_empty() {
                let i = rng.random_range(0..memory.len());
                outputstream.push(memory[i]);
            }
        }

        outputstream
    }

}
    