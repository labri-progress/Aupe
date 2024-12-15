use std::hash::{Hash, Hasher};
use std::collections::hash_map::DefaultHasher;
use std::fmt::Write; // Import the Write trait
use rand::{thread_rng, Rng};

#[derive(Debug, Clone)]
    /// Crée un nouveau Count-Min Sketch avec une largeur et une profondeur définies
pub struct CountMinSketch {
    pub width: usize,
    pub depth: usize,
    matrix: Vec<Vec<f64>>,
    hash_seeds: Vec<u64>,
    pub min_value: f64,
    pub omniscient_memory: Vec<usize>,
    pub sample_memory_size: usize,
}

impl CountMinSketch {
    /// Crée un nouveau Count-Min Sketch avec une largeur et une profondeur définies
    pub fn new(width: usize, depth: usize, sample_memory_size: usize) -> Self {
        if width == 0 || depth == 0 {
            Self {
                width,
                depth,
                matrix: Vec::new(),
                hash_seeds: Vec::new(),
                min_value: 0.0,
                omniscient_memory: Vec::new(),
                sample_memory_size,
            }
        }else {
            let matrix = vec![vec![0.0; width]; depth];
            let hash_seeds = (0..depth).map(|i| i as u64 + 1).collect();

            Self {
                width,
                depth,
                matrix,
                hash_seeds,
                min_value: f64::MAX,
                omniscient_memory: Vec::new(),
                sample_memory_size,
            }
        }
    }

    /// Fonction pour générer des indices à partir de plusieurs fonctions de hachage
    fn hash(&self, item: &impl Hash, seed: u64) -> usize {
        let mut hasher = DefaultHasher::new();
        hasher.write_u64(seed);
        item.hash(&mut hasher);
        (hasher.finish() as usize) % self.width
    }

    /// Ajoute un élément dans le Count-Min Sketch
    pub fn insert(&mut self, item: &impl Hash) {
        for (i, seed) in self.hash_seeds.iter().enumerate() {
            let index = self.hash(item, *seed);
            self.matrix[i][index] += 1.0;
        }
    }

    /* pub fn insertCU<T: Hash>(&mut self, item: &T) {
        let mut min_count = f64::MAX;
        let indices: Vec<_> = self.hash_seeds.iter().map(|&seed| self.hash(item, seed)).collect();

        //println!("indices {:?}", indices);
        for (i, &index) in indices.iter().enumerate() {
            min_count = min_count.min(self.matrix[i][index]);
        }
        //println!("min_count {}", min_count);
        for (i, &index) in indices.iter().enumerate() {
            if self.matrix[i][index] == min_count {
                self.matrix[i][index] += 1.0;
            }
        }
    } */
    /// Estime la fréquence d'un élément
    pub fn estimate(&self, item: &impl Hash) -> f64 {
        self.hash_seeds
            .iter()
            .enumerate()
            .map(|(i, seed)| self.matrix[i][self.hash(item, *seed)])  // Renvoie des f64 depuis la table
            .min_by(|a, b| a.partial_cmp(b).unwrap())  // Comparaison de f64
            .unwrap_or(0.0)
    }

    // add min
    fn min(&mut self) {
        self.min_value = f64::MAX;
        for row in &self.matrix {
            for &value in row {
                if value != 0.0 && value < self.min_value {
                    self.min_value = value;
                }
            }
        }
    }
    
    pub fn dim(&self) -> (usize, usize) {
        let rows = self.matrix.len();
        let cols = if rows > 0 { self.matrix[0].len() } else { 0 };
        (rows, cols)
    }

    pub fn matrix_to_string(&self) -> String {
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
    
        result
    }
    
    pub fn print(&self) {
        //println!("Count-Min Sketch:"); // of width {} and depth {}:", self.width, self.depth);

        for (i, row) in self.matrix.iter().enumerate() {
            println!("     Row {}: {:?}", i, row);
        }
    }
    
    pub fn merge_cms(&mut self, second_cms_matrix: Vec<Vec<f64>>) -> CountMinSketch {
        for i in 0..self.depth {
            for j in 0..self.width {
                self.matrix[i][j] += second_cms_matrix[i][j];
                self.matrix[i][j] /=2.0;
            }
        }
        // update min 
        self.min();

        self.clone()
    }

    pub fn debiais_stream_with_kfree(&mut self, inputstream: Vec<usize>) -> Vec<usize> {
        let mut outputstream = Vec::new();
        let mut rng = thread_rng();

        for element in &inputstream {
            //self.insert(element);
            
            // 2. Sample memory
            if self.omniscient_memory.len() < self.sample_memory_size {
                if !self.omniscient_memory.contains(element) {
                    self.omniscient_memory.push(*element);
                }
            }else {
                let occur :f64= self.estimate(element);
                self.min();

                let prob = self.min_value as f64/ occur as f64;
                let random_float: f64 = rand::thread_rng().gen(); 

                if random_float < prob && !self.omniscient_memory.contains(element) {
                    
                    let i = rng.gen_range(0, self.sample_memory_size);
                    
                    if let Some(tobereplaced) = self.omniscient_memory.get_mut(i) {
                        *tobereplaced = *element;
                    } else {
                        println!("Index out of bounds");
                    }
                }
            }
            let i = rng.gen_range(0, self.omniscient_memory.len());
            outputstream.push(self.omniscient_memory[i].clone());
        }
            
        outputstream
    }

    pub fn update_cms_freq(&mut self, items: Vec<usize>) {
        for item in items {
            self.insert(&item);
        }
    }

}