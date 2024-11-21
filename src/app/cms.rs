use std::hash::{Hash, Hasher};
use std::collections::hash_map::DefaultHasher;
use std::fmt::Write; // Import the Write trait

#[derive(Debug, Clone)]
pub struct CountMinSketch {
    width: usize,
    depth: usize,
    matrix: Vec<Vec<f64>>,
    hash_seeds: Vec<u64>,
    pub min_value: f64,
    pub omniscient_memory: Vec<usize>,
}

impl CountMinSketch {
    /// Crée un nouveau Count-Min Sketch avec une largeur et une profondeur définies
    pub fn new(width: usize, depth: usize) -> Self {
        if width == 0 || depth == 0 {
            Self {
                width,
                depth,
                matrix: Vec::new(),
                hash_seeds: Vec::new(),
                min_value: 0.0,
                omniscient_memory: Vec::new(),
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
    pub fn min(&mut self) {
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

    pub fn update_cms_freq(&mut self, items: Vec<usize>) {
        for item in items {
            self.insert(&item);
        }
        //Update min for the debiasing algorithm
        self.min();
    }
}