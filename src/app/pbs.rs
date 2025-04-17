use rand::{rng, Rng};
use rand::rngs::StdRng;
use rand::SeedableRng; 
use rand::prelude::SliceRandom;
use crate::net::App;
use super::aupe::Init;

use std::fmt::Write; // Import the Write trait
use std::fs;
use std::error::Error;

const SEED2: u64 = 4;
/* #[derive(Clone, Default, StructOpt, Debug)]
pub struct Init {
    /// number_of_elements_of_an_item
    #[structopt(short = "d", long = "number_of_elements", default_value = "2")]
    pub depth: usize,

    #[structopt(short = "s", long = "sm", default_value = "5")]
    pub memory_size: usize,
}  */

#[derive(Debug, Clone, Default)]
pub struct PBS {
    pub params: Init,
    pub matrix: Vec<Vec<u32>>,
    range: u8,
    order: Vec<u8>, // size of range
    pub min_value: f64,
    pub omniscient_memory: Vec<usize>,
    pub width: usize,
    n_bits: usize,
    total_items: usize,
    pub freq_array_string: String, // Matrix as string
}

impl PBS {

    pub fn get_size(&mut self, nodes: usize) {
        // Find the closest power of 2 greater than or equal to range
        
        self.range = nodes.ilog2() as u8 +1;
        
        self.n_bits = (self.range as f64 / self.params.depth as f64) as usize; //b
        
        self.width = 2f64.powi(self.n_bits as i32) as usize;
        
        while self.params.depth * self.n_bits < self.range as usize {
            self.n_bits +=1;
            self.range = (self.params.depth * self.n_bits) as u8;
            self.width = 2f64.powi(self.n_bits as i32) as usize;
        }

        /* self.n_bits = self.range as usize;
        
        self.width = 2f64.powi(self.n_bits as i32) as usize; */

        println!("n={} range={} b={} w={}", 
            nodes, self.range, self.n_bits, self.width);

        // Item maps

    }

    fn to_binary(&self, num: usize) -> Vec<usize> {
        let mut binary = Vec::new();
        let mut n = num;
    
        for _ in 0..self.range {
            binary.push(n % 2); // as u8);
            n /= 2;
        }
    
        binary.reverse(); // Reverse to get the correct binary order
        binary
    }

    fn binary_to_integer(binary: &[u8]) -> usize {
        binary.iter().fold(0, |acc, &bit| (acc << 1) | bit as usize)
    }

    fn decomposition(&self, item: usize) -> Vec<usize> {
        let binary = self.to_binary(item);
        // Decomposition and Get positions
        let mut decomposed = vec![0; self.params.depth];
        for i in 0..self.params.depth {
            let mut j = 0;
            for j in 0..self.n_bits {
                let bit = binary[self.order[i*self.n_bits+j] as usize -1];
                decomposed[i] = (decomposed[i] << 1) | bit ;
            }
        }
        decomposed
    }

    pub fn insert(&mut self, item: &usize) {
        
        let decomposed = self.decomposition(*item);
        for (i, index) in decomposed.iter().enumerate() {
            self.matrix[i][*index] += 1;
        }
    }
    
    /// Estime la fréquence d'un élément
    pub fn estimate(&self, item: &usize) -> f64 {
        let decomposed = self.decomposition(*item);

        let mut occurence :f64 = self.total_items as f64;
        for (i, index) in decomposed.iter().enumerate() {
            let value = self.matrix[i][*index] as f64 / self.total_items as f64;
            occurence = occurence * value;
        }
        occurence
    }

    fn print_full(&self) {

        for (i, row) in self.matrix.iter().enumerate() {
            println!("     Row {}: {:?}", i, row);
        }
        println!("min_value {}", self.min_value);
    }

    pub fn new() -> Self {
        Self {
            params: Init::default(),
            matrix: Vec::new(),
            range: 0,
            order: Vec::new(),
            min_value: f64::MAX,
            omniscient_memory: Vec::new(),
            width: 0,
            n_bits: 0,
            total_items: 0,
            freq_array_string: String::new(),
        }
    }
    
    pub fn print(&self) {
        println!("PBS of width {} and depth {}:", self.width, self.params.depth);
        
        let size_w = 5;
        let size_d = 1;
        for i in 0..size_d {
            print!("     Row {}: ", i);
            for j in 0..size_w {
                print!("{:?} ", self.matrix[i][j]);
            }
            println!("");
        }
        for i in 0..size_w {
            print!(" {}: {:?}", i, self.estimate(&i));
        }
        println!("\nmin_value {}", self.min_value);
        println!("...");
        //self.print_full();
    }

    pub fn name(&self) -> String{
        
        String::from("PBS(")+ &self.params.depth.to_string() + "x"+ &self.width.to_string()+"-"+&self.params.memory_size.to_string()+ ")"
    }

    pub fn to_string(&mut self) {
        let precision = 2;
        let mut result = String::new(); // Start with an empty String
    
        for (row_index, row) in self.matrix.iter().enumerate() {
            if row_index > 0 {
                result.push('\n'); // Separate rows with a newline
            }
    
            for (col_index, num) in row.iter().enumerate() {
                if col_index > 0 {
                    result.push(','); // Separate elements in a row with a comma
                }
                let _ = write!(&mut result, "{:.1$}", num, precision); // Format each number
            }
        }
    
        self.freq_array_string=result;
    }

    pub fn string_to_matrix(&mut self, input: &str)  -> Vec<Vec<u32>>{
        let result = input
            .lines() // Split the string into rows using newlines
            .map(|line| {
                line.split(',') // Split each row into elements using commas
                    .map(|num| num.trim().parse::<u32>().expect("Invalid float")) // Parse each element into u32
                    .collect::<Vec<u32>>() // Collect elements into a vector
            })
            .collect::<Vec<Vec<u32>>>(); // Collect rows into a matrix
        
        result
    }
    
    pub fn merge(&mut self, second_cms_matrix: Vec<Vec<u32>>) {
        for i in 0..self.params.depth {
            for j in 0..self.width {
                self.matrix[i][j] += second_cms_matrix[i][j];
                //self.matrix[i][j] /=2;
                self.matrix[i][j] = (self.matrix[i][j] as f64 /2.0).ceil() as u32;
            }
        }
    }

    pub fn init(&mut self, nodes: usize, init: Init) {
    
        self.params = init.clone();
        
        println!("init {:?}", self.params);

        self.get_size(nodes);
        let mut rng = StdRng::seed_from_u64(SEED2);
        let mut order:Vec<u8> = (1..self.range+1).map(|x| x).collect();

        order.shuffle(&mut rng);
        self.order = order; //vec!{1,3,4,2,5,7,6,8,9,10,11,12,13,14,16,15};//
        
        println!("order {:?}", self.order);

        self.matrix = vec![vec![0; self.width]; self.params.depth];
        
    }
    
    pub fn update_freq(&mut self, items: Vec<usize>) {
        self.total_items += items.len();
        
        for item in items {
            self.insert(&item);
        }
    }

    pub fn debiais_stream(&mut self, inputstream: Vec<usize>) -> Vec<usize> {
        
        let mut outputstream = Vec::new();
        //let mut rng = rng();
        let mut rng = StdRng::seed_from_u64(SEED2);
    
        // Insert
        self.update_freq(inputstream.clone());
        // Clean
        for element in &inputstream {
            //println!("element: {}", element);
            let occur = self.estimate(element);
            if occur > 0.0  && occur < self.min_value  {
                self.min_value = occur;
            }
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

        }
     
        outputstream
    }
   
}
    