mod net;
mod util;
mod graph;
mod rps;

mod app;

use once_cell::sync::OnceCell;
use std::sync::RwLock;

static GLOBAL_OMNISCIENT_FREQ_ARRAY: OnceCell<RwLock<Vec<isize>>> = OnceCell::new();

use structopt::StructOpt;
use net::{Simulator, App};

#[derive(StructOpt, Debug)]
#[structopt(name = "bignetrs")]
pub struct Opt {
    /// Number of simulation steps
    #[structopt(short = "T", long = "time", default_value = "100")]
    n_steps: usize,
    
    /// Number of nodes
    #[structopt(short = "n", long = "nodes", default_value = "1000")]
    nodes: usize,

    /// Show random peer samples instead of metrics after a certain time
    #[structopt(short="R", long = "random-samples")]
    random_samples: Option<usize>,

    #[structopt(subcommand)]
    app: WhichApp,
}

#[derive(StructOpt, Debug)]
pub enum WhichApp {
    /// Aupe cms serie RPS
    #[structopt(name = "serie")]
    Serie(app::serie::Init),
    
    /// Aupe CMS RPS
    #[structopt(name = "cms")]
    AupeCMS(app::aupecms::Init),
    
    /// Brahms RPS
    #[structopt(name = "brahms")]
    Brahms(app::brahms::Init),

    /// Aupe RPS
    #[structopt(name = "aupe")]
    Aupe(app::aupe::Init),

    /// Basalt RPS
    #[structopt(name = "basalt")]
    Basalt(app::basalt::Init),

    /// Basalt RPS without hit counter mechanism
    #[structopt(name = "basalt-simple")]
    BasaltSimple(app::basalt::Init),
}

fn main() {
    let opt = Opt::from_args();
    match opt.app {
        WhichApp::Serie(pp) => {
            if let Some(rs) = opt.random_samples {
                sim_rps_rng::<app::serie::Serie>(opt.n_steps, opt.nodes, &pp, rs);
            } else {
                sim::<app::serie::Serie>(opt.n_steps, opt.nodes, &pp);
            }   
        }
// cargo run -- -T 10 -n 10 cms -G samples -f 10 -x 3 -t 3 -v 5 -u 5 -m 5 -n 10 -d 2 -w 5 -p 1
// cargo run -- -T 200 -n 1000 cms -G samples -f 10 -x 100 -t 100 -v 20 -u 20 -m 100 -n 1000 -d 10 -w 272 -p 1
        WhichApp::AupeCMS(pp) => {
            if let Some(rs) = opt.random_samples {
                sim_rps_rng::<app::aupecms::AupeCMS>(opt.n_steps, opt.nodes, &pp, rs);
            } else {
                sim::<app::aupecms::AupeCMS>(opt.n_steps, opt.nodes, &pp);
            }   
        }
        WhichApp::Brahms(pp) => {
            //println!("Brahms");
            if let Some(rs) = opt.random_samples {
                sim_rps_rng::<app::brahms::Brahms>(opt.n_steps, opt.nodes, &pp, rs);
            } else {
                sim::<app::brahms::Brahms>(opt.n_steps, opt.nodes, &pp);
            }   
        }
        WhichApp::Aupe(pp) => {
            //println!("Aupe");
            if let Some(rs) = opt.random_samples {
                sim_rps_rng::<app::aupe::Aupe>(opt.n_steps, opt.nodes, &pp, rs);
            } else {
                sim::<app::aupe::Aupe>(opt.n_steps, opt.nodes, &pp);
            }   
        }
        WhichApp::BasaltSimple(mut pp) => {
            pp.use_hit_counter = false;
            //println!("BasaltSimple");
            if let Some(rs) = opt.random_samples {
                sim_rps_rng::<app::basalt::Basalt>(opt.n_steps, opt.nodes, &pp, rs);
            } else {
                sim::<app::basalt::Basalt>(opt.n_steps, opt.nodes, &pp);
            }
        }
        WhichApp::Basalt(mut pp) => {
            pp.use_hit_counter = true;
            if let Some(rs) = opt.random_samples {
                sim_rps_rng::<app::basalt::Basalt>(opt.n_steps, opt.nodes, &pp, rs);
            } else {
                sim::<app::basalt::Basalt>(opt.n_steps, opt.nodes, &pp);
            }
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

fn sim_rps_rng<A: App + rps::RPS + Send>(nsteps: usize, nproc: usize, init: &A::Init, first_output_round: usize) {
    let mut net = Simulator::<A>::new(nproc, init);

    for step in 0..nsteps {
        net.step();
        if step >= first_output_round {
            let i = nproc - 1;
            //for i in (nproc/2)..nproc {
                for r in net.processes[i].state.get_samples() {
                    println!("{}", r);
                }
            //}
        }
    }
}
