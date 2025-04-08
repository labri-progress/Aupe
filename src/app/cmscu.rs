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
pub struct CmsCu {
    pub params: Init,
    pub matrix: Vec<Vec<u32>>,
    pub hash_seeds: Vec<u64>,
    pub min_value: u32,
    pub omniscient_memory: Vec<usize>,
    pub freq_array_string: String,
}


impl CmsCu {
    fn hash(&self, item: &impl Hash, seed: u64) -> usize {
        let mut hasher = DefaultHasher::new();
        hasher.write_u64(seed);
        item.hash(&mut hasher);
        (hasher.finish() as usize) % self.params.width
    }

    /// Conservative update
    /* fn insert(&mut self, item: &impl Hash) {
        let mut min_count = u32::MAX;
        let indices: Vec<_> = self.hash_seeds.iter().map(|&seed| self.hash(item, seed)).collect();

        println!("indices {:?}", indices);
        for (i, &index) in indices.iter().enumerate() {
            min_count = min_count.min(self.matrix[i][index]);
        }
        //println!("min_count {}", min_count);
        for (i, &index) in indices.iter().enumerate() {
            if self.matrix[i][index] == min_count {
                self.matrix[i][index] += 1;
            }
        }
    } */

    pub fn insert(&mut self, item: &impl Hash) {
        
        let min_count = self.estimate(item);
        //const threshold: u32 = 31;
        // panic if min_count i greater than threshold
        /* if min_count > threshold {
            panic!("min_count {} is greater than threshold {}", min_count, threshold);
        } */
        for (i, seed) in self.hash_seeds.iter().enumerate() {
            let index = self.hash(item, *seed);
            if self.matrix[i][index] == min_count {
                self.matrix[i][index] += 1;
            }
        }
    }
    
    /// Estime la fréquence d'un élément
    pub fn estimate(&self, item: &impl Hash) -> u32 {
        self.hash_seeds
            .iter()
            .enumerate()
            .map(|(i, seed)| self.matrix[i][self.hash(item, *seed)]) 
            .min() 
            .unwrap_or(0)
    }

    fn print_full(&self) {

        for (i, row) in self.matrix.iter().enumerate() {
            println!("     Row {}: {:?}", i, row);
        }
        println!("min_value {}", self.min_value);
    }

    pub fn min(&mut self) {
        self.min_value = u32::MAX;
        for row in &self.matrix {
            for &value in row {
                if value != 0 && value < self.min_value {
                    self.min_value = value;
                }
            }
        }
    }

    pub fn new() -> Self {
        Self {
            params: Init::default(),
            matrix: Vec::new(),
            hash_seeds: Vec::new(),
            min_value: u32::MAX,
            omniscient_memory: Vec::new(),
            freq_array_string: String::new(),
        }
    }
    
    fn print(&self) {
        println!("CMSCU of width {} and depth {}:", self.params.width, self.params.depth);
        let size = 3;
        for i in 0..size {
            print!("     Row {}: ", i);
            for j in 0..size {
                print!("{:?} ", self.matrix[i][j]);
            }
            println!("");
        }
        for i in 0..size {
            print!(" {}: {:?}", i, self.estimate(&i));
        }
        println!("min_value {}", self.min_value);
        println!("...");
        //self.print_full();
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
            for j in 0..self.params.width {
                self.matrix[i][j] += second_cms_matrix[i][j];
                //self.matrix[i][j] /=2;
                self.matrix[i][j] = (self.matrix[i][j] as f64 /2.0).ceil() as u32;
            }
        }
    }

    fn name(&self) -> String{
        
        String::from("CMSCU(")+ &self.params.depth.to_string() + "x"+ &self.params.width.to_string()+"-"+&self.params.memory_size.to_string()+ ")"
    }

    fn init(&mut self, _:usize, init: Init) {
    
        self.params = init;
        
        println!("init {:?}", self.params);

        self.matrix = vec![vec![0; self.params.width]; self.params.depth];
        self.hash_seeds = (0..self.params.depth).map(|i| i as u64 + 1).collect();

    }
    
    fn update_freq(&mut self, items: Vec<usize>) {
        for item in items {
            self.insert(&item);
        }
        //Update min for the debiasing algorithm
        self.min();
    }

    /* fn debiais_stream(&mut self, inputstream: Vec<usize>) -> Vec<usize> {
        
        let mut outputstream = Vec::new();
        //let mut rng = thread_rng();
        let mut rng = StdRng::seed_from_u64(SEED2);
    
        // Insert
        self.update_freq(inputstream.clone());
        // Clean
        for element in &inputstream {
            //println!("element: {}", element);
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
    