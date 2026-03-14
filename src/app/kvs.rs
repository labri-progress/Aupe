use rand::{rng, Rng};
//use crate::net::App;
use super::aupe::Init;

use std::fmt::Write; // Import the Write trait
use std::fs;
use std::error::Error;

use rand::rngs::StdRng;
use rand::SeedableRng; 
use crate::util::SEED2;

#[derive(Debug, Clone)]
pub struct Kvs {
    params: Init,
    omn_array: Vec<f64>, // size n
    min_index: usize, 
    min_value: f64,
    omniscient_memory: Vec<usize>,
    pub freq_array_string: String,
}

impl Kvs {
    pub fn min(&mut self) {
        self.min_value = f64::MAX;
        for (index, &value) in self.omn_array.iter().enumerate() {
            if value > 0.0  && value < self.min_value  {
                self.min_value = value;
                self.min_index = index;
            }
        }
    }

    pub fn new() -> Self {
        Self {
            params: Init::default(),
            omn_array: Vec::new(),
            min_value: f64::MAX,
            min_index: 0,
            omniscient_memory: Vec::new(), 
            freq_array_string: String::new(),
        }
    }
    
    pub fn print(&self) {
        for i in 0..10 {
            print!(" {}: {:?}", i, self.omn_array[i]);
        }
        println!("");
        println!("min_value {}", self.min_value);
        println!("...");
    }

    pub fn getdata(&self) -> Vec<f64>{
        return self.omn_array.clone()
    }
    
    pub fn copy(&mut self, new_vec: Vec<f64>) {
        self.omn_array = new_vec;
    }

    pub fn merge(&mut self, second_vec: Vec<f64>) {
        for i in 0..self.omn_array.len() {
            self.omn_array[i] += second_vec[i];
            self.omn_array[i] /=2.0;
        }
    }

    pub fn init(&mut self, nodes: usize, init: Init) {
    
        self.params = init;
        self.omn_array = vec![0.0; nodes];
        
    }

    pub fn update_freq(&mut self, items: Vec<usize>) {
        for item in items {
            self.omn_array[item] += 1.0;
        }
        self.min();
    }

    pub fn estimate(&mut self, item: &usize) -> f64 {

        self.omn_array[*item]
    }

    pub fn debiais_stream(&mut self, inputstream: Vec<usize>, rng: &mut StdRng) -> Vec<usize> {
        let mut outputstream = Vec::new();

        //let mut rng =  StdRng::seed_from_u64(SEED2); 

        for element in &inputstream {
            //println!("element: {}", element);
            let occur = self.omn_array[*element];

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
                //println!("prob: {}", prob);
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
    