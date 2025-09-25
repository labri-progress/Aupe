use rand::{rng, Rng};
//use crate::net::App;
use super::aupe::Init;

use std::fmt::Write; // Import the Write trait
use std::fs;
use std::error::Error;

/* #[derive(Clone, Default, StructOpt, Debug)]
pub struct Init {
    #[structopt(short = "s", long = "sm", default_value = "5")]
    pub memory_size: usize,
}  */
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

    pub fn to_string(&mut self) {
        let precision = 2;
        let mut result = String::with_capacity(self.omn_array.len() * (precision + 3)); // Allocate some capacity to reduce reallocations
        for (i, num) in self.omn_array.iter().enumerate() {
            if i > 0 {
                result.push(','); // Append a comma between elements
            }
            // Use a buffer to format the number directly
            let _ = write!(&mut result, "{:.1$}", num, precision);
        }
        self.freq_array_string = result;
    }

    pub fn string_to_vec(&mut self, input: &str) -> Vec<f64>{
        let result = input
        .split(',')
        .map(str::trim) // Trim whitespace
        .map(|s| s.parse::<f64>().expect("Invalid integer in input")) // Parse and panic on error
        .collect::<Vec<f64>>(); // Collect into a Vec<u32>
         
        result
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

    pub fn debiais_stream(&mut self, inputstream: Vec<usize>) -> Vec<usize> {
        let mut outputstream = Vec::new();

        let mut rng = rng();

        for element in &inputstream {
            //println!("element: {}", element);
            let occur = self.omn_array[*element];

            if self.omniscient_memory.len() < self.params.memory_size {

                if !self.omniscient_memory.contains(element) {
                    self.omniscient_memory.push(*element);
                }

            }else {
                let prob = self.min_value / occur;
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
    