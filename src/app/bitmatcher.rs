use rand::{rng, Rng};
use rand::rngs::StdRng;
use rand::SeedableRng; 
use rand::prelude::SliceRandom;

use structopt::StructOpt;

use super::aupebm::Init;

use cxx::UniquePtr;
use cxx::CxxString;
use std::pin::Pin;

use crate::util::SEED2;

#[cxx::bridge(namespace = "org::blobstore")]
pub mod ffi {
    unsafe extern "C++" {
        include!("aupe/include/bitmatcher.h");

        type BitMatcher;

        fn new_bitmatcher(bucket: u64) -> UniquePtr<BitMatcher>;
        fn Insert(self: Pin<&mut BitMatcher>, key: &CxxString, key_len: i16); 
        fn Query(self: Pin<&mut BitMatcher>, key: &CxxString, key_len: i16) -> f64;
        fn print_buckets(self: &BitMatcher);
        fn merge(self: Pin<&mut BitMatcher>, other: &BitMatcher);
        fn clone(self: &BitMatcher)-> UniquePtr<BitMatcher>;
        fn get_blocked_count(self: &BitMatcher) -> u32;
        fn get_division_count(self: &BitMatcher) -> u32;
    }
}
unsafe impl Send for ffi::BitMatcher {}
unsafe impl Sync for ffi::BitMatcher {}
impl Clone for BM {
    fn clone(&self) -> Self {
        BM {
            params: self.params.clone(),
            matrix: self.matrix.as_ref().unwrap().clone(), 
            key_len: self.key_len,
            min_value: self.min_value,
            omniscient_memory: self.omniscient_memory.clone(),
        }
    }
}

use crate::app::bitmatcher::ffi::BitMatcher;


use cxx::let_cxx_string;

pub struct BM {
    pub params: Init,
    pub matrix: UniquePtr<BitMatcher>,
    pub key_len: usize,
    pub min_value: f64,
    pub omniscient_memory: Vec<usize>,
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
        if result !=0.0 && result < self.min_value {
            self.min_value = result;
        }
        result
    }

    pub fn new() -> Self {
        Self {
            params: Init::default(),
            matrix: ffi::new_bitmatcher(0),
            key_len: 4,
            min_value: f64::MAX,
            omniscient_memory: Vec::new(),
        }
    }
    
    pub fn print(& self) {
        //println!("BM of 2 arrays, each of {:?} buckets of size 64 bits", self.params.n_bucket); 
        self.matrix.print_buckets();
        println!("\nmin_value {}", self.min_value);
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
        //println!("init {:?}", self.params);
        /* if self.params.n_bucket == 0 {
            self.params.n_bucket = self.params.space * 1024 / 8 / 2;
        } */
        self.matrix = ffi::new_bitmatcher(self.params.n_bucket);
        
    }

    pub fn get_stats(&self) -> (u32, u32) {
        (self.matrix.get_blocked_count(), self.matrix.get_division_count())
    }

    pub fn update_freq(&mut self, mut items: Vec<usize>) {

        for item in items {
            self.insert(&item);
        }
    }

    pub fn getdata(&self) -> UniquePtr<BitMatcher>{
        return self.matrix.as_ref().unwrap().clone()
    }

    pub fn copy(&mut self, other: &BitMatcher) {
        self.matrix = other.clone();
    }

    pub fn merge(&mut self, other: &BitMatcher) {
        //self.matrix.as_mut().unwrap().merge(&other);
        self.matrix.as_mut().unwrap().merge(other);
    }
    

    pub fn debiais_stream(&mut self, inputstream: Vec<usize>, rng: &mut StdRng) -> Vec<usize> {
        let mut outputstream = Vec::new();
        
        for element in &inputstream {
            
            let occur = self.estimate(element);
            
            if self.omniscient_memory.len() < self.params.memory_size {
                if !self.omniscient_memory.contains(element) {
                    self.omniscient_memory.push(*element);
                }
            }else {
                let mut prob;
                if occur == 0.0 {
                    prob = 1.0;
                } else {
                    prob = self.min_value/ occur as f64;
                }
                let random_float: f64 = rng.random(); 
                if random_float < prob && !self.omniscient_memory.contains(element) {
                    let i = rng.random_range(0..self.params.memory_size);//omniscient_memory.len());
                    
                    self.omniscient_memory[i] = *element;
                }
            }
            let i = rng.random_range(0..self.omniscient_memory.len());
            outputstream.push(self.omniscient_memory[i].clone());
        }
     
        outputstream
    }
   
}
    