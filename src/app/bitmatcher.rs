use rand::{rng, Rng};
use rand::rngs::StdRng;
use rand::SeedableRng; 
use rand::prelude::SliceRandom;

use structopt::StructOpt;

use super::aupebm::Init;

use cxx::UniquePtr;
use cxx::CxxString;
use std::pin::Pin;

#[cxx::bridge(namespace = "org::blobstore")]
mod ffi {
    // Shared structs with fields visible to both languages.
    /* struct BlobMetadata {
        size: usize,
        tags: Vec<String>,
    }

    // Rust types and signatures exposed to C++.
    extern "Rust" {
        type MultiBuf;

        fn next_chunk(buf: &mut MultiBuf) -> &[u8];
    } */

    // C++ types and signatures exposed to Rust.
    unsafe extern "C++" {
        include!("aupe/include/bitmatcher.h");

        type BitMatcher;

        fn new_bitmatcher(bucket: u64) -> UniquePtr<BitMatcher>;
        fn Insert(self: Pin<&mut BitMatcher>, key: &CxxString, key_len: i16); //key: &str,key_len: u16);
        //double Query(const char *key, const int16_t key_len = 0) 
        fn Query(self: Pin<&mut BitMatcher>, key: &CxxString, key_len: i16) -> f64;
        fn print_buckets(self: &BitMatcher);
    }
}
unsafe impl Send for ffi::BitMatcher {}
unsafe impl Sync for ffi::BitMatcher {}

use crate::app::bitmatcher::ffi::BitMatcher;

/* #[derive(Clone, Default, StructOpt, Debug)]
pub struct Init {
    /// number_of_elements_of_an_item
    #[structopt(short = "c", long = "n_bucket", default_value = "0")]
    pub n_bucket: u64,

    #[structopt(short = "s", long = "sm", default_value = "5")]
    pub sample_memory_size: usize,

    #[structopt(short = "b", long = "budget", default_value = "5")]
    pub space: u64,

}  */

use cxx::let_cxx_string;

pub struct BM {
    pub params: Init,
    pub matrix: UniquePtr<BitMatcher>,
    pub key_len: usize,
    pub min_value: f64,
    pub omniscient_memory: Vec<usize>,
    pub freq_array_string: String,
}

fn count_digits(n: usize) -> usize {
    n.to_string().chars().count()
}

impl BM {

    pub fn insert(&mut self, item: &usize) { 

        let item_str = format!("{:0>width$}", item, width = self.key_len);
        //println!("insert item: {}", item_str);
        let_cxx_string!(key = item_str);
        self.matrix.as_mut().unwrap().Insert(&key, self.key_len as i16)
    }
    
    /// Estime la fréquence d'un élément
    pub fn estimate(&mut self, item: &usize) -> f64 {

        let item_str = format!("{:0>width$}", item, width = self.key_len);
        let_cxx_string!(key = item_str);
        let result = self.matrix.as_mut().unwrap().Query(&key, self.key_len as i16);
        //println!("item {} occurence {}", item, result);
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
            freq_array_string: String::new(),
        }
    }
    
    pub fn print(& self) {
        println!("BM of 2 arrays, each of {:?} buckets of size 64 bits", self.params.n_bucket); 
        self.matrix.print_buckets();
        //println!("\nmin_value {}", self.min_value);
    }

    pub fn getparams(&mut self, init: Init) {
        self.params = init;
        self.params.n_bucket = self.params.space * 1024 / 8 / 2;
    }

    pub fn init(&mut self, nodes: usize, init: Init) {
    
        self.getparams(init.clone());
        self.key_len = count_digits(nodes -1);
        //println!("init {:?}", self.params);
        if self.params.n_bucket == 0 {
            self.params.n_bucket = self.params.space * 1024 / 8 / 2;
        }
        self.matrix = ffi::new_bitmatcher(self.params.n_bucket);
        
    }

    pub fn update_freq(&mut self, mut items: Vec<usize>) {

        for item in items {
            self.insert(&item);
        }
    }

    pub fn to_string(&mut self) {

    }

    pub fn string_to_matrix(&mut self, input: &str)  -> Vec<Vec<f64>>{
        Vec::new()
    }
    
    pub fn merge(&mut self, second_cms_matrix: Vec<Vec<f64>>) {
    
    }
    
    pub fn debiais_stream(&mut self, inputstream: Vec<usize>) -> Vec<usize> {
        
        let mut outputstream = Vec::new();
        let mut rng = rng();
        
        for element in &inputstream {
            
            let occur = self.estimate(element);
            
            if self.omniscient_memory.len() < self.params.memory_size {
                if !self.omniscient_memory.contains(element) {
                    self.omniscient_memory.push(*element);
                }
            }else {
                
                let prob = self.min_value/ occur as f64;
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


    fn count_occurence_and_frequency(&mut self, system_size: usize, real_occurences: Vec<f64>) -> (Vec<f64>, Vec<f64>){
        let mut occurences = vec![0.0; system_size];
        let mut frequencies = vec![0.0; system_size];

        for id in 0..system_size {
            if real_occurences[id] != 0.0 {
                occurences[id]=self.estimate(&id);
               // let decomposed = self.decomposition(id);
                //println!("item {} = {:?}", id, decomposed);
                if occurences[id] > 0.0  && occurences[id] < self.min_value  {
                    self.min_value = occurences[id];
                }
            }
        }
        let sum = occurences.iter().sum::<f64>(); 
        for (i, &occurrence) in occurences.iter().enumerate() {
            frequencies[i] = occurrence / sum;
        }
        
        (occurences, frequencies)
    }
   
}
    