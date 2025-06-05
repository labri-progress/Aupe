#![allow(warnings)]

mod net;
mod util;
mod graph;
mod app;
use structopt::StructOpt;
use net::{Simulator, App};
use once_cell::sync::OnceCell;
use std::sync::RwLock;

static GLOBAL_OMNISCIENT_FREQ_ARRAY: OnceCell<RwLock<Vec<isize>>> = OnceCell::new();

#[derive(StructOpt, Debug)]
#[structopt(name = "bignetrs")]
pub struct Opt {
    /// Number of simulation steps
    #[structopt(short = "T", long = "time", default_value = "100")]
    n_steps: usize,
    
    /// Number of nodes
    #[structopt(short = "n", long = "nodes", default_value = "1000")]
    nodes: usize,

    #[structopt(subcommand)]
    app: WhichApp,
}

#[derive(StructOpt, Debug)]
pub enum WhichApp {
    
    /// Aupe CMS RPS
    /* #[structopt(name = "cms")]
    AupeCMS(app::aupecms::Init), */

    /// Aupe RPS
    #[structopt(name = "aupe")]
    Aupe(app::aupe::Init),

    /// Brahms RPS
    #[structopt(name = "brahms")]
    Brahms(app::brahms::Init),

}

fn main() {
    let opt = Opt::from_args();
    match opt.app {
// cargo run -- -T 10 -n 10 cms -G samples -f 10 -x 3 -t 3 -v 5 -u 5 -m 5 -n 10 -d 2 -w 5 -p 1
// cargo run -- -T 200 -n 1000 cms -G samples -f 10 -x 100 -t 100 -v 20 -u 20 -m 100 -n 1000 -d 10 -w 272 -p 1
        /* WhichApp::AupeCMS(pp) => {
            sim::<app::aupecms::AupeCMS>(opt.n_steps, opt.nodes, &pp);  
        } */
// cargo run -- -T 200 -n 1000 aupe -O -G samples -f 10 -t 240 -x 0 -v 20 -u 20 -m 100 -n 1000 -p 9

// cargo run -- -T 200 -n 1000 aupe -G samples -f 10 -t 300 -v 20 -u 20 -m 10 -n 1000 
// cargo run -- -T 200 -n 1000 aupe -G samples -f 10 -t 300 -v 20 -u 20 -m 10 -n 1000 -x 100 -p 5
        WhichApp::Aupe(pp) => {
            sim::<app::aupe::Aupe>(opt.n_steps, opt.nodes, &pp);  
        }
// cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 300 -v 20 -u 20 -k 0 -r 1
        WhichApp::Brahms(pp) => {
            sim::<app::brahms::Brahms>(opt.n_steps, opt.nodes, &pp);  
        }
    }
}

fn sim<A: App + Send>(nsteps: usize, nproc: usize, init: &A::Init) {
    GLOBAL_OMNISCIENT_FREQ_ARRAY.set(RwLock::new(vec![-1; nproc])).unwrap();

    let mut net = Simulator::<A>::new(nproc, init);
    net.print_header();
    net.print_metrics();
    /* println!("--------------------------------");
    println!(" END OF ROUND");
    println!("--------------------------------"); */
    for _step in 0..nsteps {
        net.step();
        net.print_metrics();
        /* println!("--------------------------------");
		println!(" END OF ROUND {}", _step+1);
		println!("--------------------------------"); */
    }
}