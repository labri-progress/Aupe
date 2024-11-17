use std::hash::{Hash, Hasher};
use std::collections::hash_map::DefaultHasher;

#[derive(Debug, Clone)]
pub struct CountMinSketch {
    width: usize,
    depth: usize,
    matrix: Vec<Vec<f64>>,
    hash_seeds: Vec<u64>,
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
            }
        }else {
            let matrix = vec![vec![0.0; width]; depth];
            let hash_seeds = (0..depth).map(|i| i as u64 + 1).collect();

            Self {
                width,
                depth,
                matrix,
                hash_seeds,
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

    pub fn print(&self) {
        println!("Count-Min Sketch:");

        for (i, row) in self.matrix.iter().enumerate() {
            println!("     Row {}: {:?}", i, row);
        }
    }

    pub fn merge_cms(&mut self, second_omn_array: CountMinSketch) -> CountMinSketch {

        for i in 0..self.depth {
            for j in 0..self.width {
                self.matrix[i][j] += second_omn_array.matrix[i][j];
                self.matrix[i][j] /=2.0;
            }
        }
        self.clone()
    }
}