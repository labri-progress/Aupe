use rand::{rng, Rng};
//use crate::net::App;
use super::aupe::Init;

use std::hash::{Hash, Hasher};
use std::collections::hash_map::DefaultHasher;

use std::fmt::Write; // Import the Write trait
use std::fs;
use std::error::Error;

/* #[derive(Clone, Default, StructOpt, Debug)]
pub struct Init {
    /// number_of_hash_function
    #[structopt(short = "h", long = "number_of_hash_functions", default_value = "2")]
    pub depth: usize,

    /// Number_of_discrete_values
    #[structopt(short = "w", long = "number_of_discrete_values", default_value = "5")]
    pub width: usize,

    #[structopt(short = "s", long = "sm", default_value = "5")]
    pub memory_size: usize,
}  */

#[derive(Debug, Clone, Default)]
pub struct BF {
    pub params: Init,
    pub counters: Vec<f64>,
    pub hash_seeds: Vec<u64>,
    pub min_value: f64,
    pub omniscient_memory: Vec<usize>,
    pub freq_array_string: String,
}


impl BF {
    fn hash(&self, item: &impl Hash, seed: u64) -> usize {
        let mut hasher = DefaultHasher::new();
        hasher.write_u64(seed);
        item.hash(&mut hasher);
        (hasher.finish() as usize) % self.params.width
    }

    pub fn insert(&mut self, item: &impl Hash) {
        
        let min_count = self.estimate(item);

        for (i, seed) in self.hash_seeds.iter().enumerate() {
            let index = self.hash(item, *seed);
            if self.counters[index] == min_count {
                self.counters[index] += 1.0;
            }
        }
    }
    
    /// Estime la fréquence d'un élément
    pub fn estimate(&self, item: &impl Hash) -> f64 {
        self.hash_seeds
            .iter()
            .enumerate()
            .map(|(i, seed)| self.counters[self.hash(item, *seed)]) 
            .min_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal)) // Handle float comparison safely
            .unwrap_or(0.0)
    }

    fn print_full(&self) {

        println!("     Counters {:?}", self.counters);
        
        println!("min_value {}", self.min_value);
    }

    pub fn min(&mut self) {
        self.min_value = f64::MAX;
        for value in &self.counters {
            if *value != 0.0 && *value < self.min_value {
                self.min_value = *value;
            }
        }
    }

    pub fn new() -> Self {
        Self {
            params: Init::default(),
            counters: Vec::new(),
            hash_seeds: Vec::new(),
            min_value: f64::MAX,
            omniscient_memory: Vec::new(),
            freq_array_string: String::new(),
        }
    }
    
    fn print(&self) {
        println!("BF of width {} and depth {}:", self.params.width, self.params.depth);
        let size = 5;
        for i in 0..size {
            print!("{} ", self.counters[i]);
        }
        println!("...");
        for i in 0..size {
            print!(" {}: {:?}", i, self.estimate(&i));
        }
        println!("min_value {}", self.min_value);
        println!("...");
        //self.print_full();
    }

    pub fn to_string(&mut self) {
        let precision = 2;
        let mut result = String::with_capacity(self.counters.len() * (precision + 3)); // Allocate some capacity to reduce reallocations
        for (i, num) in self.counters.iter().enumerate() {
            if i > 0 {
                result.push(','); // Append a comma between elements
            }
            // Use a buffer to format the number directly
            let _ = write!(&mut result, "{:.1$}", num, precision);
        }
        self.freq_array_string = result;
    }

    pub fn string_to_vec(&mut self, input: &str)  -> Vec<f64>{
        //println!("string_to_vec {:?}", input);
        let result = input
        .split(',')
        .map(str::trim) // Trim whitespace
        .map(|s| s.parse::<f64>().expect("Invalid integer in input")) // Parse and panic on error
        .collect::<Vec<f64>>(); // Collect into a Vec<u32>
        
        result
    }

    pub fn merge(&mut self, second_vec: Vec<f64>) {
        //println!("merging {:?} with {:?}", self.counters, second_vec);
        for i in 0..self.counters.len() {
            let mut flag = true;
            if self.counters[i]*second_vec[i] == 0.0{
                flag = false;
            }
            self.counters[i] += second_vec[i];
            if flag {
                self.counters[i] = self.counters[i] /2.0;
            }
            
            //self.counters[i] = self.counters[i].min(second_vec[i]);
        }
    }

    fn name(&self) -> String{
        
        String::from("BF(")+ &self.params.depth.to_string() + "x"+ &self.params.width.to_string()+"-"+&self.params.memory_size.to_string()+ ")"
    }

    fn init(&mut self, _:usize, init: Init) {
    
        self.params = init;
        
        println!("init {:?}", self.params);

        self.counters = vec![0.0; self.params.width];
        self.hash_seeds = (0..self.params.depth).map(|i| i as u64 + 1).collect();

    }
    
    fn update_freq(&mut self, items: Vec<usize>) {
        for item in items {
            self.insert(&item);
        }
        //Update min for the debiasing algorithm
        self.min();
    }
/* 
    fn debiais_stream(&mut self, inputstream: Vec<usize>) -> Vec<usize> {
        
        let mut outputstream = Vec::new();
        //let mut rng = thread_rng();
        let mut rng = StdRng::seed_from_u64(SEED2);
    
        // Insert
        self.update_freq(inputstream.clone());
        // Clean
        for element in &inputstream {
            println!("element: {}", element);
            let occur = self.estimate(element);
            // 2. Sample memory
            if self.omniscient_memory.len() < self.params.memory_size {
                if !self.omniscient_memory.contains(element) {
                    self.omniscient_memory.push(*element);
                }
            }else {
                
                let prob = self.min_value as f64/ occur as f64;
                //println!("prob: {}", prob);
                let random_float: f64 = rng.random(); 
                if random_float < prob && !self.omniscient_memory.contains(element) {
                    let i = rng.random_range(0..self.params.memory_size);//omniscient_memory.len());
                    if let Some(tobereplaced) = self.omniscient_memory.get_mut(i) {
                        *tobereplaced = *element;
                    } else {
                        println!("Index out of bounds");
                    }
                }
            }
            let i = rng.random_range(0..self.omniscient_memory.len());
            outputstream.push(self.omniscient_memory[i].clone());
            //println!("sample memory: {:?}", self.omniscient_memory);
            //println!("output stream: {:?}", outputstream);

        }
     
        outputstream
    }
 */
}
    