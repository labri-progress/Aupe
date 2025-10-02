use std::hash::{Hash, Hasher};
use fasthash::*;
use rand::{rng, Rng};
use super::net::PeerRef;
use rand::seq::SliceRandom;
use rand::rngs::StdRng;
use rand::SeedableRng;
pub const SEED2: u64 = 42;

pub fn either_or_if_both<T: Clone>(a: &Option<T>, b: &Option<T>, f: fn(&T, &T) -> T) -> Option<T> {
    match (a, b) {
        (None, x) => x.clone(),
        (x, None) => x.clone(),
        (Some(x), Some(y)) => Some(f(x, y)),
    }
}

pub fn hash(seed: u64, peer: PeerRef) -> u64 {
    //return seed ^ (peer as u64);
    let mut s = XXHasher::default();
    seed.hash(&mut s);
    peer.hash(&mut s);
    s.finish()
}

pub fn sample_exclude<T, R: Rng + ?Sized>(from: Vec<usize>, to: &mut Vec<usize>, n: usize, id: usize, rng: &mut R)
        where
            T: PartialEq + Clone {

    while to.len() < n {
        let i = rng.random_range(0..from.len());
        if !to.contains(&from[i]) && from[i].clone() != id {
            to.push(from[i].clone());
        }
    }
}

pub fn sample<T: PartialEq + Clone, R: Rng + ?Sized>(from: &[T], n: usize, rng: &mut R) -> Vec<T> {
    if n >= from.len() {
        return from.to_vec();
    }
    
    if n >= from.len() / 4 {
        let mut ret = from.to_vec();
        //ret.shuffle(&mut rng);
        ret.shuffle(rng);
        ret.drain(..n).collect::<Vec<T>>()
    } else {
        let mut ret = vec![];
        while ret.len() < n {
            let i = rng.random_range(0..from.len());
            if !ret.contains(&from[i]) {
                ret.push(from[i].clone());
            }
        }
        ret
    }
}

pub fn sample_nocopy<T: PartialEq + Clone, R: Rng + ?Sized>(from: &mut [T], n: usize, rng: &mut R) -> Vec<T> {
    if n >= from.len() {
        return from.to_vec();
    }
    
    if n >= from.len() / 4 {
        //rng.shuffle(from);
        from.shuffle(rng);
        from[..n].iter().cloned().collect::<Vec<T>>()
    } else {
        let mut ret = vec![];
        while ret.len() < n {
            let i = rng.random_range(0..from.len());
            if !ret.contains(&from[i]) {
                ret.push(from[i].clone());
            }
        }
        ret
    }
}

pub fn print_samples(sample_view: &mut Vec<(u64, Option<PeerRef>)>) {
    print!("SampleList [");
    for (_, opt_peer_ref) in sample_view.iter_mut() {
        if let Some(peer_ref) = opt_peer_ref {
            print!("{:?} ", peer_ref);
        }
    }
    println!("]");
}

/* 
use std::fmt::Write; // Import the Write trait
use std::fs;
use std::error::Error;

use std::fs::{File, OpenOptions};
use std::io::{self};

pub fn write_results(data:Vec<usize>,file_path:&str) -> io::Result<()> {

    let mut file = OpenOptions::new()
        .append(true)
        .create(true)
        .open(file_path)?; 
    
    let data_str = data.iter()
                .map(|e| e.to_string())
                .collect::<Vec<String>>()
                .join(" ");
    
    use std::io::Write;
    writeln!(file, "{}", data_str)?; 

    Ok(())
} */