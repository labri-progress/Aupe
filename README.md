# Aupe

Rscript fig1_evolution_strategies.r 0.5 [zoom_from zoom_to]

Rscript fig2_convergence_summary.r 0.5 [round_from] [round_to]

Rscript fig3_merge_gain.r 0.5 [round_from] [round_to]

Rscript fig4_attack_comparison.r 0.5 9900 11000

Rscript fig5_kmeans_nodes.r 0.5 [p_merge] [round_from] [round_to]

Rscript fig6_trust_gap.r 0.5 [round_from] [round_to]


./max_expe.sh decay2 2 10 0 ; ./max_expe.sh decay2 2 30 20 ;
./max_expe.sh decay2 2 20 0 ; ./max_expe.sh decay2 2 40 20 ;

./max_expe.sh decay2 2 10 0 ; ./max_expe.sh decay2 2 30 0 ;
./max_expe.sh decay2 2 20 0 ; ./max_expe.sh decay2 2 40 0 ;

./max_expe.sh decay2 1 10 0 ; ./max_expe.sh decay2 1 30 0 ;
./max_expe.sh decay2 1 20 0 ; ./max_expe.sh decay2 1 40 0;


cargo run -- -T 200 -n 10000 basalt -f 10 -t 1000 -v 160 -i 160 -k 1 -r 1 > basalt10
cargo run -- -T 200 -n 10000 brahms -f 10 -t 1000 -v 160 -u 160 > brahms10

cargo run -- -T 200 -n 10000 basalt -f 10 -t 2000 -v 160 -i 160 -k 1 -r 1 > basalt20
cargo run -- -T 200 -n 10000 brahms -f 10 -t 2000 -v 160 -u 160 > brahms20

cargo run -- -T 200 -n 10000 brahms -f 10 -t 2000 -v 160 -u 160 

cargo run -- -T 200 -n 10000 -d 1 decay2 -f 10 -t 3000 -v 160 -u 160 -m 100 -n 10000 -y 5 -x 3000 -p 1

cargo run -- -T 200 -n 1000 -d 1 decay2 -f 10 -t 300 -v 100 -u 100 -m 100 -n 1000 -c 32 -x 300 -p 1 > decay

# basic expe

./max_expe.sh decay2 0.5 40 5 1 4 ; ./max_expe.sh decay2 0.5 40 20 1 4 ;
./max_expe.sh decay2 0.5 40 0 1 4 ; ./max_expe.sh decay2 0.5 40 10 1 4 ;

./max_expe.sh decay2 0.5 30 5 1 4 ; ./max_expe.sh decay2 0.5 30 20 1 4 ;
./max_expe.sh decay2 0.5 30 0 1 4 ; ./max_expe.sh decay2 0.5 30 10 1 4 ;

./max_expe.sh decay2 0.5 20 5 1 4 ; ./max_expe.sh decay2 0.5 20 20 1 4 ;
./max_expe.sh decay2 0.5 20 0 1 4 ; ./max_expe.sh decay2 0.5 20 10 1 4 ;

./max_expe.sh decay2 0.5 10 5 1 4 ; ./max_expe.sh decay2 0.5 10 20 1 4 ;
./max_expe.sh decay2 0.5 10 0 1 4 ; ./max_expe.sh decay2 0.5 10 10 1 4 ;

./max_expe.sh decay2 0.5 10 30 1 4 ; ./max_expe.sh decay2 0.5 30 30 1 4 ;
./max_expe.sh decay2 0.5 20 30 1 4 ; ./max_expe.sh decay2 0.5 40 30 1 4 ;


# end

./max_expe.sh decay4 0.5 10 0 ; ./max_expe.sh decay4 0.5 10 20 ;
./max_expe.sh decay4 0.5 20 0 ; ./max_expe.sh decay4 0.5 20 20 ;
./max_expe.sh decay4 0.5 30 0 ; ./max_expe.sh decay4 0.5 30 20 ;
./max_expe.sh decay4 0.5 40 0 ; ./max_expe.sh decay4 0.5 40 20 ;


./max_expe.sh basalt 0.5 10 0 1 4 ; ./max_expe.sh basalt 0.5 30 0 1 4 ;
./max_expe.sh basalt 0.5 20 0 1 4 ; ./max_expe.sh basalt 0.5 40 0 1 4 ;




./max_expe.sh bm 0.5 10 0 ; ./max_expe.sh bm 0.5 25 0 ;
./max_expe.sh bm 0.5 20 0 ; ./max_expe.sh bm 0.5 35 0 ;
./max_expe.sh bm 0.5 30 0 ; ./max_expe.sh bm 0.5 40 0 ;

./max_expe.sh brahms 0.5 10 0 ; ./max_expe.sh brahms 0.5 25 0 ;
./max_expe.sh brahms 0.5 20 0 ; ./max_expe.sh brahms 0.5 35 0 ;
./max_expe.sh brahms 0.5 30 0 ; ./max_expe.sh brahms 0.5 40 0 ;

./max_expe.sh array 0.5 40 5 ; ./max_expe.sh array 0.5 40 20 ;
./max_expe.sh array 0.5 40 0 ; ./max_expe.sh array 0.5 40 10 ;

./max_expe.sh array 0.5 30 5 ; ./max_expe.sh array 0.5 30 20 ;
*./max_expe.sh array 0.5 30 0* ; ./max_expe.sh array 0.5 30 10 ;

./max_expe.sh array 0.5 20 5 ; ./max_expe.sh array 0.5 20 20 ;
./max_expe.sh array 0.5 20 0 ; ./max_expe.sh array 0.5 20 10 

./max_expe.sh array 0.5 10 5 ; ./max_expe.sh array 0.5 10 20 ;
./max_expe.sh array 0.5 10 0 ; ./max_expe.sh array 0.5 10 10 ;



# Plots
J'ai une liste de scripts à faire pour la génération de diverses figures, destinée à un papier journal double column de 12 pages. Produis les script R associés en respectant le format des fichiers de résultat présents dans le dossier output_byz (le dossier ne contient qu'une ébauche des résultats pour le moment). 
Fais également des choix de réprésentation clair et digeste pour ce papier (couleurs uniformisés, choix de type de ligne ou de forme de points lorsque nécessaire, échelle, etc...)
L'ensemble de mes simulations respectent le format 20000 rounds, avec une attaque débutant au round 10000. 
les proportions de byzantins qui nous insteressent sont 10, 20, 30 et 40%.
Tu peux t'inspirer des 3 scripts r actuellement présents dans le dossier. 

1. Figure qui montre l'évolution de la proportion de byzantin dans la vue des noeuds corrects (colonne avgByzN comme d'habitude) en fonction des rounds. Les stratégies évaluées sont Aupe Array (stratégie array dans les fichiers de résultat), Aupe BM (bm), Aupe BMDecay (decay2). 

2. Figure recapitulative qui montre la proportion de byzantin dans la vue des noeuds corrects à la convergence (calculée comme la moyenne sur les 9000 derniers rounds) en fonction du pourcentage de byzantin dans le système. Les stratégies évaluées sont Basalt, Brahms et Aupe BMDecay

3. Figure recapitulative qui montre le gain sur la proportion de byzantin dans la vue des noeuds corrects des stratégies Aupe BMDecay avec Merge t=5, 10 et 20% par rapport à la version Aupe BmDecay sans merge. La proportion est aussi mesurée à la convergence.

4. Figure qui montre l'évolution de la proportion de byzantin dans la vue des noeuds corrects en fonction des rounds, en comparant AupeBMDecay pour une attaque classique, i.e. débutant au round 10000 (stratégie decay2) et AupeBMDecay pour une attaque dans laquelle les byzantins ne se répresentent pas du tout avant le round 10000 (decay 4). On doit pouvoir évaluer cela lorsqu'il n'y a pas de merge (t=0%) et lorsqu'il y a du merge 5, 10, 20%. Trouve des noms adéquats pour ces 2 configurations de AupeBMDecay dans le cas de cette figure.

5. script qui analyse les proportions de byzantin dans la vue de chacun des noeuds corrects (fichier de résultat débutant par nodes-) du round 11000 au round 11049 (valeurs tunables), afin de classifier qui sont les noeuds de confiance et qui sont les autres noeuds corrects. Les noeuds de confiance sont attendus d'avoir des vues moins biaisées et donc la moyenne de la proportion de byzantin sur ces 50 rounds doit être plus faible que pour un simple noeud correct. Fais une classification Kmeans à 2 classe. Les métriques étudiées sont precision, recal F1score. Les vraies classes sont définies dans le codes rust : 0 à F-1 pour les byzantins. F à F+T-1 pour les noeuds de confiance et le reste pour les autres noeuds corrects.

La stratégie à analyser est decay2. En abcisse on a la valeur de precision/recal/f1 de 0 à 1. En ordonné on a la proportion de byzantin et on affiche différentes courbes pour le svaleurs de t possibles (t=5, 10, 20)

Remarque:
- Comme dans le fichier plot_three_figures.r, donne la possibilité de pouvoir zoomer la figure entre 2 rounds donnés tout en affichant plus de points
- pour toutes les figures, mets la proportion de byzantin entre 0 et 1
prop of byz sampl is betwen 0 and 1 also
tous les textes des figures en anglais
il manque les labels de l'axe y dans la figure 3
les figures qui ont 4 grilles pour f=10-40%, doivent aligner les 4 grilles sur une lêle ligne horizontale. 
Diminue l'échelle des figures aussi. elles seront importées dans un document double colonne

6. Rajoute également une figure 6 qui montre la différence entre la proportion de byzantin dans la vue des noeuds de confiance (colonne t_avgByzN) et dans la vue des noeuds corrects (h_avgByzN), toujours en faisant cette moyenne des valeurs sur les rounds 11000 à round 11049.


7. Rajoute le lot de figures 7 qui montrent l'évolution de la proportion de byzantin dans la vue des noeuds corrects (colonne avgByzN comme d'habitude) en fonction des rounds. Les stratégies évaluées sont Aupe Array (stratégie array), Brahms (brahms) et Basalt (basalt). 
Deuxieme la figure recapitulative qui montre la proportion de byzantin dans la vue des noeuds corrects à la convergence (calculée comme la moyenne sur les 9000 derniers rounds) en fonction du pourcentage de byzantin dans le système. Les stratégies évaluées sont les mêmes
Troisiemement la figure recapitulative qui montre la proportion de byzantin dans la vue des noeuds corrects à la convergence  en fonction du pourcentage de byzantin dans le système. Les stratégies évaluées sont les mêmes + AupeBMDecay



./max_expe.sh decay5 0.5 10 0 ; ./max_expe.sh decay5 0.5 10 20 ;
./max_expe.sh decay5 0.5 20 0 ; ./max_expe.sh decay5 0.5 20 20 ;
./max_expe.sh decay5 0.5 30 0 ; ./max_expe.sh decay5 0.5 30 20 ;
./max_expe.sh decay5 0.5 40 0 ; ./max_expe.sh decay5 0.5 40 20 ;

./max_expe.sh decay5 0.5 10 5 ; ./max_expe.sh decay5 0.5 10 10 ;
./max_expe.sh decay5 0.5 20 5 ; ./max_expe.sh decay5 0.5 20 10 ;
./max_expe.sh decay5 0.5 30 5 ; ./max_expe.sh decay5 0.5 30 10 ;
./max_expe.sh decay5 0.5 40 5 ; ./max_expe.sh decay5 0.5 40 10 ;