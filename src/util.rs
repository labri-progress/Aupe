use std::hash::{Hash, Hasher};
use fasthash::*;
use rand::{thread_rng, Rng};

use super::net::PeerRef;

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

pub fn sample<T: PartialEq + Clone>(from: &[T], n: usize) -> Vec<T> {
    if n >= from.len() {
        return from.to_vec();
    }

    let mut rng = thread_rng();
    if n >= from.len() / 4 {
        let mut ret = from.to_vec();
        rng.shuffle(&mut ret[..]);
        ret.drain(..n).collect::<Vec<T>>()
    } else {
        let mut ret = vec![];
        while ret.len() < n {
            let i = rng.gen_range(0, from.len());
            if !ret.contains(&from[i]) {
                ret.push(from[i].clone());
            }
        }
        ret
    }
}

pub fn sample_nocopy<T: PartialEq + Clone>(from: &mut [T], n: usize) -> Vec<T> {
    if n >= from.len() {
        return from.to_vec();
    }

    let mut rng = thread_rng();
    if n >= from.len() / 4 {
        rng.shuffle(from);
        from[..n].iter().cloned().collect::<Vec<T>>()
    } else {
        let mut ret = vec![];
        while ret.len() < n {
            let i = rng.gen_range(0, from.len());
            if !ret.contains(&from[i]) {
                ret.push(from[i].clone());
            }
        }
        ret
    }
}

/* fn contains_value(from: &[isize], value: isize) -> Option<usize> {
    from.iter().position(|&x| x == value)
} */

pub fn get_min_key_value(from: &[f64]) -> Option<(usize, f64)> {
    let mut min_value = None;
    let mut min_index = None;

    for (index, &value) in from.iter().enumerate() {
        if value > 0.0 {
            match min_value {
                Some(v) if value < v => {
                    min_value = Some(value);
                    min_index = Some(index);
                },
                None => {
                    min_value = Some(value);
                    min_index = Some(index);
                },
                _ => {}
            }
        }
    }
    match (min_index, min_value) {
        (Some(i), Some(v)) => Some((i, v)),
        _ => None,
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

pub fn print_vector_with_two_digits(v: Vec<f64>, total:f64) {
    print!("[");
    for num in v {
        print!("{:.2} ", num);
    }
    print!("]({ })", total);
}