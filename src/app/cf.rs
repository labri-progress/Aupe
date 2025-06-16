use crate::app::cmscu::CmsCu;
use crate::app::bf::BF;

use rand::{rng, Rng};
//use crate::net::App;
use super::aupecf::Init;

use std::hash::{Hash, Hasher};
use std::collections::hash_map::DefaultHasher;

use std::fmt::Write; // Import the Write trait
use std::fs;
use std::error::Error;

/* #[derive(Clone, Default, StructOpt, Debug)]
pub struct Init {
    ///Cold Filter params
    /// 
    /// Threshold value of layer 1
    #[structopt(short = "a", long = "threshold_layer_1", default_value = "15")]
    pub t1: u32,

    /// Threshold value of layer 2
    #[structopt(short = "b", long = "threshold_layer_2", default_value = "15")]
    pub t2: u32,

    /// number_of_hash_function of layer i
    #[structopt(short = "i", long = "layer_i_number_of_hash_functions", default_value = "5")]
    pub replicates: usize,

    /// Number_of_discrete_values of layer 1
    #[structopt(long = "w1", default_value = "5")]
    pub counter1: usize,

    /// Number_of_discrete_values of layer 2
    #[structopt(long = "w2", default_value = "5")]
    pub counter2: usize,

    ///Sketch params
    ///
    /// number_of_hash_function
    #[structopt(short = "h", long = "number_of_hash_functions", default_value = "5")]
    pub depth: usize,

    /// Number_of_discrete_values
    #[structopt(short = "w", long = "number_of_discrete_values", default_value = "5")]
    pub width: usize,

    #[structopt(short = "s", long = "sm", default_value = "5")]
    pub memory_size: usize,
} 
 */

 #[derive(Debug, Clone, Default)]
pub struct CF {
    pub params: Init,
    layer1: BF,
    layer2: CmsCu,
    sketch: CmsCu,
    pub min_value: f64,
    pub omniscient_memory: Vec<usize>,
    pub freq_array_string: Vec<String>,
}


impl CF {
    /// CF algorithm: returns wheteher it is a cold item or not
    fn insert(&mut self, item: &impl Hash) -> bool{
        let v1 = self.layer1.estimate(item);
        if v1 < self.params.t1 as f64{
            self.layer1.insert(item); // Cold item
            true
        }else {
            let v2 = self.layer2.estimate(item); 
            if v2 < self.params.t2 as f64{
                self.layer2.insert(item); // Hot item
                true
            }else {
                self.sketch.insert(item); // Very hot item
                false
            }
        }
    }

    /// Estime la fréquence d'un élément
    pub fn estimate(&self, item: &impl Hash) -> f64 {
        let v1 = self.layer1.estimate(item);
        if v1 < self.params.t1 as f64{
            v1 // Cold item
        }else {
            let v2 = self.layer2.estimate(item); 
            if v2 < self.params.t2 as f64{
                v1 + v2 // Hot item
            }else {
                v1 + v2 + self.sketch.estimate(item) // Very hot item
            }
        }
    }

    fn min(&mut self) {
        self.layer1.min();
        self.min_value = self.layer1.min_value;
        if self.layer1.min_value == self.params.t1 as f64{
            self.layer2.min();
            self.min_value = self.params.t1 as f64+ self.layer2.min_value;
            if self.layer2.min_value == self.params.t2 as f64{
                self.sketch.min();
                self.min_value = (self.params.t1 + self.params.t2) as f64 + 
                    self.sketch.min_value;
            }
        }
    }

    pub fn new() -> Self {
        Self {
            params: Init::default(),
            layer1: BF::new(),
            layer2: CmsCu::new(),
            sketch: CmsCu::new(),
            min_value: f64::MAX,
            omniscient_memory: Vec::new(),
            freq_array_string: Vec::new(),
        }
    }
    
    pub fn print(&self) {
        println!("Colf Filter");
        //print!("{:?} ", self.layer1.counters);
        println!("Layer 1 of width {} and depth {}: threshold {}", 
            self.params.counter1, self.params.replicates, self.params.t1);
        let size = 3;
        for i in 0..size {
            print!("{} ", self.layer1.counters[i]);
        }
        println!("...");

        println!("Layer 2 of width {} and depth {}: threshold {}", 
            self.params.counter2, self.params.replicates, self.params.t2);
        for i in 0..size {
            print!("     Row {}: ", i);
            for j in 0..size {
                print!("{:?} ", self.layer2.matrix[i][j]);
            }
            println!("");
        }

        println!("SKetch of width {} and depth {}:", self.params.width, self.params.depth);
        for i in 0..size {
            print!("     Row {}: ", i);
            for j in 0..size {
                print!("{:?} ", self.sketch.matrix[i][j]);
            }
            println!("");
        }
        //print!("{:?} ", self.sketch.matrix);
        //println!("Cold items: {:?} ({})", self.cold_items, self.cold_items.len());
        for i in 0..size {
            print!(" {}: {:?}", i, self.estimate(&i));
        }
        println!(" min_value {}", self.min_value);
        println!("...");
        //self.print_full();
    }

    pub fn to_string(&mut self, num: usize) {

        if num==0 {
            self.layer1.to_string();
            self.freq_array_string[0] = self.layer1.freq_array_string.clone();
        }else if num==1 {
            self.layer2.to_string();
            self.freq_array_string[1] = self.layer2.freq_array_string.clone();
        }else if num==2 {   
            self.sketch.to_string();
            self.freq_array_string[2] = self.sketch.freq_array_string.clone();
        }else { //if num==3 {
            self.layer1.to_string();
            self.layer2.to_string();
            self.sketch.to_string();

            self.freq_array_string[0] = self.layer1.freq_array_string.clone();
            self.freq_array_string[1] = self.layer2.freq_array_string.clone();
            self.freq_array_string[2] = self.sketch.freq_array_string.clone();
        }
    }

    pub fn string_to_matrix(&mut self, num: usize, layer:&str) -> Vec<Vec<f64>>{
        
        if num==0 {
            let mut res = Vec::new();
            res.push(self.layer1.string_to_vec(layer));
            res
        }else if num==1 {
            self.layer2.string_to_matrix(layer)
        }else {//if num==2 {   
            self.sketch.string_to_matrix(layer)
        }
        /*else {
            println!("Error: num should be 0, 1 or 2");
            None
        }*/

    }

    pub fn merge(&mut self, num: usize, layer: Vec<Vec<f64>>) {
        //print!("<<<<<<<<<<<<<merging layer {}", num);
        if num==0 {
            self.layer1.merge(layer[0].clone());
        }else if num==1 {
            self.layer2.merge(layer);
        }else if num==2 {   
            self.sketch.merge(layer);
        }else {
            println!("Error: num should be 0, 1 or 2. Not {}", num);
        }

        // update min 
        self.min();

    }

    fn name(&self) -> String{
        
        String::from("CF(")+ &self.params.depth.to_string() + "x"+ &self.params.width.to_string()+"-"+&self.params.memory_size.to_string()+ ")"
    }

    pub fn getparams(&mut self, init: Init) {
        self.params = init;
        match self.params.space  {
            6 => {
                self.params.counter1 = 10000;
                self.params.counter2 = 245;
                self.params.t1 = 15;
                self.params.t2 = 31;
            },
            12 => {
                self.params.counter1 = 20000;
                self.params.counter2 = 1600;
                self.params.t1 = 31;
                self.params.t2 = 63;
            },
            0_u64..=5_u64 | 7_u64..=11_u64 | 13_u64..=u64::MAX => todo!(),
        }
    }

    pub fn init(&mut self, _:usize, init: Init) {
    
        self.getparams(init.clone());

        self.freq_array_string = vec![String::new(); 3];
        self.sketch.matrix = vec![vec![0.0; self.params.width]; self.params.depth];
        self.sketch.hash_seeds = (0..self.params.depth).map(|i| i as u64 + 1).collect();
        self.sketch.params.depth = self.params.depth;
        self.sketch.params.width = self.params.width;
        //self.sketch.params.memory_size = self.params.memory_size;
        //self.layer1.matrix = vec![vec![0; self.params.counter1]; self.params.replicates];
        self.layer1.counters = vec![0.0; self.params.counter1];
        self.layer1.hash_seeds = (0..self.params.replicates).map(|i| i as u64 + 1).collect();
                //.map(|i| i as u64 + self.params.depth as u64 + 1).collect();
        self.layer1.params.depth = self.params.replicates;
        self.layer1.params.width = self.params.counter1;

        self.layer2.matrix = vec![vec![0.0; self.params.counter2]; self.params.replicates];
        self.layer2.hash_seeds = (0..self.params.replicates).map(|i| i as u64 + 1).collect();
                //.map(|i| i as u64 + self.params.replicates as u64 + self.params.depth as u64 + 1).collect();
        self.layer2.params.depth = self.params.replicates;
        self.layer2.params.width = self.params.counter2;

        // compute logarithm of 2 and rount to sup inteeger
        
        let gamma1 = (self.params.t1 as f64).log2().ceil() as usize;
        let gamma2 = (self.params.t2 as f64).log2().ceil() as usize;
        let gamma = 32;
        
        let mcf = self.layer1.params.depth * self.layer1.params.width * gamma1 + 
            self.layer2.params.depth * self.layer2.params.width * gamma2 ;
        
    }
    
    pub fn update_freq(&mut self, items: Vec<usize>) {
        for item in items {
            self.insert(&item);
            //print!("{}: {} ", item, self.estimate(&item));
        }
        //Update min for the debiasing algorithm
        self.min(); //Update min in cold_items
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
                let prob = self.min_value as f64/ occur as f64;
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
    