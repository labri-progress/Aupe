use rand::{rng, Rng};
use crate::net::App;
use super::aupe::Init;

/* #[derive(Clone, Default, StructOpt, Debug)]
pub struct Init {
    #[structopt(short = "s", long = "sm", default_value = "5")]
    pub memory_size: usize,
}  */
#[derive(Debug, Clone)]
pub struct Kvs {
    params: Init,
    omn_array: Vec<u32>, // size n
    min_index: usize, 
    min_value: u32,
    omniscient_memory: Vec<usize>,
}

impl Kvs {
    pub fn min(&mut self) {
        self.min_value = u32::MAX;
        for (index, &value) in self.omn_array.iter().enumerate() {
            if value > 0  && value < self.min_value  {
                self.min_value = value;
                self.min_index = index;
            }
        }
    }

    pub fn new() -> Self {
        Self {
            params: Init::default(),
            omn_array: Vec::new(),
            min_value: u32::MAX,
            min_index: 0,
            omniscient_memory: Vec::new(), 
        }
    }
    
    fn print(&self) {
        for i in 0..10 {
            print!(" {}: {:?}", i, self.omn_array[i]);
        }
        println!("");
        println!("min_value {}", self.min_value);
        println!("...");
    }


    pub fn init(&mut self, nodes: usize, init: Init) {
    
        self.params = init;
        self.omn_array = vec![0; nodes];
        
    }

    pub fn update_freq(&mut self, items: Vec<usize>) {
        for item in items {
            self.omn_array[item] += 1;
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
    