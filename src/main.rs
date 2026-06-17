#![allow(warnings)]

mod net;
mod util;
mod graph;
mod app;
use structopt::StructOpt;
use net::{Simulator, App};

const folder: &str = "results_merge";

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
    
    /// Aupe BM RPS
    #[structopt(name = "bm")]
    AupeBM(app::aupebm::Init),

    /// Aupe CF RPS
    /* #[structopt(name = "cf")]
    AupeCF(app::aupecf::Init), */

    /// Aupe RPS
    #[structopt(name = "decay")]
    AupeDecay(app::aupebmdecay::Init),

    /// Aupe RPS – debiasing par présence physique (prob=1 si absent, min/max si présent)
    #[structopt(name = "decay2")]
    AupeDecay2(app::aupebmdecay2::Init),

    /// Aupe RPS – query avg-bucket (moy des compteurs du bucket si présent, sinon original)
    #[structopt(name = "decay3")]
    AupeDecay3(app::aupebmdecay3::Init),

    /// Aupe RPS – byzantins invisibles avant attack_start (pas de push, exclus des vues initiales)
    #[structopt(name = "decay4")]
    AupeDecay4(app::aupebmdecay4::Init),

    /// Eviction Decay RPS
    #[structopt(name = "evict")]
    EvictionDecay(app::evictiondecay::Init),

    /// X Decay RPS
    #[structopt(name = "xdec")]
    XDecay(app::xdecay::Init),


    /// X BM RPS
    #[structopt(name = "xbm")]
    XBM(app::xbm::Init),

    /// X Array RPS
    #[structopt(name = "xarray")]
    XArray(app::xarray::Init),

    /// Aupe RPS
    #[structopt(name = "array")]
    Aupe(app::aupe::Init),

    /// Brahms RPS
    #[structopt(name = "brahms")]
    Brahms(app::brahms::Init),

    /// Baslt RPS
    #[structopt(name = "basalt")]
    Basalt(app::basalt::Init),
}

fn main() {
    let opt = Opt::from_args();
    match opt.app {
// cargo run -- -T 10 -n 10 cms -G samples -f 10 -x 3 -t 3 -v 5 -u 5 -m 5 -n 10 -d 2 -w 5 -p 1
// cargo run -- -T 200 -n 1000 bm -G samples -f 10 -t 100 -v 20 -u 20 -m 100 -n 1000 -y 6 
        /* WhichApp::AupeCF(pp) => {
            sim::<app::aupecf::AupeCF>(opt.n_steps, opt.nodes, &pp);  
        } */ 
        WhichApp::AupeDecay(pp) => {
            let f = format!("{}/nodes-decay-{}-{}-{}-{}-{}-{:.1}.csv",
                folder, pp.nodes, pp.view_size, pp.n_byzantine, pp.n_trusted, pp.nb_merge, pp.space);
            sim::<app::aupebmdecay::AupeDecay>(opt.n_steps, opt.nodes, &pp, &f, pp.nb_merge);
        }

        WhichApp::AupeDecay2(pp) => {
            let f = format!("{}/nodes-decay2-{}-{}-{}-{}-{}-{:.1}.csv",
                folder, pp.nodes, pp.view_size, pp.n_byzantine, pp.n_trusted, pp.nb_merge, pp.space);
            sim::<app::aupebmdecay2::AupeDecay2>(opt.n_steps, opt.nodes, &pp, &f, pp.nb_merge);
        }

        WhichApp::AupeDecay3(pp) => {
            let f = format!("{}/nodes-decay3-{}-{}-{}-{}-{}-{:.1}.csv",
                folder, pp.nodes, pp.view_size, pp.n_byzantine, pp.n_trusted, pp.nb_merge, pp.space);
            sim::<app::aupebmdecay3::AupeDecay3>(opt.n_steps, opt.nodes, &pp, &f, pp.nb_merge);
        }

        WhichApp::AupeDecay4(pp) => {
            let f = format!("{}/nodes-decay4-{}-{}-{}-{}-{}-{:.1}.csv",
                folder, pp.nodes, pp.view_size, pp.n_byzantine, pp.n_trusted, pp.nb_merge, pp.space);
            sim::<app::aupebmdecay4::AupeDecay4>(opt.n_steps, opt.nodes, &pp, &f, pp.nb_merge);
        }

        WhichApp::EvictionDecay(pp) => {
            let f = format!("{}/nodes-evict-{}-{}-{}-{}-{}-{:.1}.csv",
                folder, pp.nodes, pp.view_size, pp.n_byzantine, pp.n_trusted, pp.nb_merge, pp.space);
            sim::<app::evictiondecay::EvictionDecay>(opt.n_steps, opt.nodes, &pp, &f, pp.nb_merge);
        }

        WhichApp::XDecay(pp) => {
            let f = format!("{}/nodes-xdec-{}-{}-{}-{}-{}-{:.1}.csv",
                folder, pp.nodes, pp.view_size, pp.n_byzantine, pp.n_trusted, pp.nb_merge, pp.space);
            sim::<app::xdecay::XDecay>(opt.n_steps, opt.nodes, &pp, &f, pp.nb_merge);
        }

        /*WhichApp::MergeDecay(pp) => {
            let f = format!("{}/nodes-mdec-{}-{}-{}-{}-{}-{:.1}.csv",
                folder, pp.nodes, pp.view_size, pp.n_byzantine, pp.n_trusted, pp.nb_merge, pp.space);
            sim::<app::mergedecay::MergeDecay>(opt.n_steps, opt.nodes, &pp, &f, pp.nb_merge);
        }*/

        
        WhichApp::AupeBM(pp) => {
            let f = format!("{}/nodes-bm-{}-{}-{}-{}-{}-{:.1}.csv",
                folder, pp.nodes, pp.view_size, pp.n_byzantine, pp.n_trusted, pp.nb_merge, pp.space);
            sim::<app::aupebm::AupeBM>(opt.n_steps, opt.nodes, &pp, &f, pp.nb_merge);
        }

        WhichApp::XBM(pp) => {
            let f = format!("{}/nodes-xbm-{}-{}-{}-{}-{}-{:.1}.csv",
                folder, pp.nodes, pp.view_size, pp.n_byzantine, pp.n_trusted, pp.nb_merge, pp.space);
            sim::<app::xbm::XBM>(opt.n_steps, opt.nodes, &pp, &f, pp.nb_merge);
        }

// cargo run -- -T 200 -n 1000 aupe -O -G samples -f 10 -t 240 -x 0 -v 20 -u 20 -m 100 -n 1000 -p 9

// cargo run -- -T 200 -n 1000 aupe -G samples -f 10 -t 300 -v 20 -u 20 -m 10 -n 1000
// cargo run -- -T 200 -n 1000 aupe -G samples -f 10 -t 300 -v 20 -u 20 -m 10 -n 1000 -x 100 -p 5
        WhichApp::Aupe(pp) => {
            let f = format!("{}/nodes-array-{}-{}-{}-{}-{}.csv",
                folder, pp.nodes, pp.view_size, pp.n_byzantine, pp.n_trusted, pp.nb_merge);
            sim::<app::aupe::Aupe>(opt.n_steps, opt.nodes, &pp, &f, pp.nb_merge);
        }

        WhichApp::XArray(pp) => {
            let f = format!("{}/nodes-xarray-{}-{}-{}-{}-{}.csv",
                folder, pp.nodes, pp.view_size, pp.n_byzantine, pp.n_trusted, pp.nb_merge);
            sim::<app::xarray::XArray>(opt.n_steps, opt.nodes, &pp, &f, pp.nb_merge);
        }

// cargo run -- -T 200 -n 1000 brahms -G samples -f 10 -t 300 -v 20 -u 20 -k 0 -r 1
        WhichApp::Brahms(pp) => {
            let f = format!("{}/nodes-brahms-{}-{}-{}.csv",
                folder, opt.nodes, pp.view_size, pp.n_byzantine);
            sim::<app::brahms::Brahms>(opt.n_steps, opt.nodes, &pp, &f, 0);
        }
// cargo run -- -T 2000 -n 1000 basalt -G -f 10 -t 300 -v 20 -i 20 -k 1 -r 1
        WhichApp::Basalt(pp) => {
            let f = format!("{}/nodes-basalt-{}-{}-{}.csv",
                folder, opt.nodes, pp.view_size, pp.n_byzantine);
            sim::<app::basalt::Basalt>(opt.n_steps, opt.nodes, &pp, &f, 0);
        }
    }
}

fn sim<A: App + Send>(nsteps: usize, nproc: usize, init: &A::Init, node_file: &str, nb_merge: usize) {

    let mut net = Simulator::<A>::new(nproc, init);
    net.print_header();
    if nb_merge > 0 {
        net.write_node_header(node_file);
    }
    net.print_metrics();
    if nb_merge > 0 {
        net.write_node_metrics(node_file);
    }
    let mut list_of_steps = vec![100, 500, 9999, 10500, 20000];
    list_of_steps.extend(11000usize..=11049);
    for _step in 0..nsteps {
        net.step();
        net.print_metrics();
        if nb_merge > 0 && list_of_steps.contains(&(_step + 1)) {
            net.write_node_metrics(node_file);
        }
    }
}