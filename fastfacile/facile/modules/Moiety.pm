###############################################################################
# File:     Moiety.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Package to identify constraints and moieties.
##############################################################################
# Detailed Description:
# ---------------------
#
###############################################################################

package Moiety;

use strict;
use diagnostics;          # equivalent to -w command-line switch
use warnings;

use vars qw(@ISA @EXPORT);

require Exporter;
@ISA = qw(Exporter);

# these subroutines are imported when you use Moiety.pm
@EXPORT = qw(
	     stoichMatrix
	    );

#######################################################################################
# INSTANCE METHODS
#######################################################################################

#------------------------------------------------
#stoichiometric stuff
# TO DO
#
# * we are modifying hashes after tests are done on them, may have problems
# e.g. if new entry for rateList exits, what would it happen?
# * if kernel is scalar, things may not work. This may occur if
# there is a single constraint: variable=constant.
#
#
# REFERENCE: Sauro HM, Ingalls B., "Conservation analysis in biochemical networks:
#            computational issues for software writers.",
#            Biophys Chem. 2004 Apr 1;109(1):1-15.
#
#-------------------------------------------
sub stoichMatrix {
    my $self = shift;
    my $stoi_file=shift;

    my $reaction_list_ref = $self->get_reaction_list();
    my $node_list_ref = $self->get_node_list();
    my $variable_list_ref = $self->get_variable_list();

    my $compartment_volume = $self->get_config_ref()->{compartment_volume};

    # create list of free/nonfree node objects and sort according to (non)free_index,
    # if free/nonfree index is defined, means input file designated node as such
    # (index corresponds to input file ordering)
    my @free_nodes = grep(defined $_->get_free_index(), $node_list_ref->get_list());
    my @nonfree_nodes = grep(defined $_->get_nonfree_index(), $node_list_ref->get_list());
    my @ordered_free_nodes = sort {$a->get_free_index() <=> $b->get_free_index()} @free_nodes;
    # we reverse the following list to make sure that variables will be created below in the
    # same order as the nonfree specifications of the user in the equation file, since
    # creation order will determine the order in which these variables get printed
    my @ordered_nonfree_nodes = reverse sort {$a->get_nonfree_index() <=> $b->get_nonfree_index()} @nonfree_nodes;

    # now just map the object handles to the node names
    my @free_node_names = map ($_->get_name(), @ordered_free_nodes);
    my @nonfree_node_names = map ($_->get_name(), @ordered_nonfree_nodes);

    # now get all nodes that were not designated as free or nonfree in input file
    my @nondesignated_nodes = grep(!defined $_->get_free_index() && !defined $_->get_nonfree_index(), $node_list_ref->get_list());
    my @nondesignated_node_names = map ($_->get_name(), @nondesignated_nodes);

    # now concatenate the three lists
    my @node_names = (@free_node_names, @nondesignated_node_names, @nonfree_node_names);

    ## Reverse node_names so that free variables go to end of list before
    ## ... moving onto constraint identification.
    @node_names=reverse(@node_names);
    ### end reorder

    ### Construct the stoichiometry matrix
    my @stoich;
    # for each row (node, ode)
    for (my $k = 0; $k < @node_names; $k++) {
	my $nodeName = $node_names[$k];
	my $node_ref = $node_list_ref->lookup_by_name($nodeName);
	$stoich[$k] = [(0) x $reaction_list_ref->get_count()];  # initialize row to zero
	my @create_reactions = $node_ref->get_create_reactions();
	# increment by 1 for each create reaction
	foreach my $create_reaction_ref (@create_reactions) {
	    my $j = $create_reaction_ref->get_index();
	    $stoich[$k][$j]++;
	}
	# decrement by 1 for each destroy reaction
	my @destroy_reactions = $node_ref->get_destroy_reactions();
	foreach my $destroy_reaction_ref (@destroy_reactions) {
	    my $j = $destroy_reaction_ref->get_index();
	    $stoich[$k][$j]--;
	}
    }
    ### end construct
    my @reactions = $reaction_list_ref->get_list();
    #print "Stoichiometry matrix row labels: ".(join ",", @node_names). "\n";
    #print "Stoichiometry matrix column labels:\n".(join "\n", (map {$_->get_source_line()} @reactions)). "\n";
    #print "Stoichiometry matrix: \n";print2d(@stoich);


    ### output stoichiometry matrix to text file
    if($stoi_file){
	open(FILE, ">$stoi_file");
	foreach my $st ( @stoich ) {print FILE "@$st\n";};
	print FILE "\n%row labels\n";
	foreach my $node ( @node_names ) {print FILE "%$node\n";};
	close(FILE);
	print "\nNote: stoichiometry matrix output to $stoi_file\n";
    }
    ### end output

    ### Merge columns of the stoichiometry matrix which have identical velocities
    ### This is equivalent to grouping terms in the associated ODEs
    my @velocities = map ($_->get_velocity(), @reactions);
    my %velocity_to_column_mapping;
    my @unique_velocities;
    for (my $i=0; $i < @velocities; $i++) {
	push @unique_velocities, $velocities[$i] if !exists $velocity_to_column_mapping{"$velocities[$i]"};
	push @{$velocity_to_column_mapping{"$velocities[$i]"}}, $i;
    }

    my @merged_stoich;
    for (my $i=0; $i < @unique_velocities; $i++) {
	foreach my $column (@{$velocity_to_column_mapping{"$velocities[$i]"}}) {
	    for (my $k = 0; $k < @node_names; $k++) {
		$merged_stoich[$k][$i] += $stoich[$k][$column];
	    }
	}
    }
    #print "Stoichiometry matrix (merged): \n";print2d(@merged_stoich);
    @stoich = @merged_stoich;
    ### End of merge

    ### find kernels and construct constraints
    ###

    ### obtain left kernel
    my @nullSp=l_null(@stoich);
    ### if empty kernel, exit
    if(@nullSp<1){print "Note: no constraint found.\n\n";return;};
    ### reduced row echelon form of left kernel (normally not necessary)
    @nullSp=rref(@nullSp);

    ### construct array containing constraints in readable form
    my @cnstr;
    for(my $i=0;$i<@nullSp;$i++){
	my @tmp;
	for(my $j=0;$j<=$#{$nullSp[$i]};$j++){
	    if ($nullSp[$i][$j]!=0){
		push(@tmp,{'coef' => $nullSp[$i][$j],'var_name' => $node_names[$j]});
	    }
	}
	$cnstr[$i]=[ @tmp ];
    }
    ### end construct

    ### check that first term of each constraint has coefficient 1
    for (my $i=0;$i<@cnstr;$i++){
	if($cnstr[$i][0]{'coef'} != 1){ #TODO: tolerance
	    print "\nERROR: the kernel is not in reduced form.\n
        Something went wrong with the \"reduced row echelon form\" function"}
    }
    ### end check

    ### check that free/non-free variables specified...
    ### by user are indeed so after constraining.
    my @constrained_var;
    for(my $i=0;$i<@cnstr;$i++){
	push @constrained_var, $cnstr[$i][0]{'var_name'};
    }
    foreach my $free_node_name (@free_node_names){ # test free variables
	if(grep(/^$free_node_name$/,@constrained_var)){
	    print "\nWarning: unable to keep $free_node_name unconstrained.\n";
	}
    }
    foreach my $nonfree_node_name (@nonfree_node_names){
	if(!grep(/^$nonfree_node_name$/,@constrained_var)){ # test non-free variables
	    print "\nWarning: unable to constrain $nonfree_node_name.\n";
	}
    }
    ### end check

    ## use stoichiometric matrix to find constrained nodes, designate them
    ## as constrained, and print out the corresponding expressions
    print "\nThe constrained variables are:\n";
    for(my $i=0; $i < @cnstr; $i++){
	# the constrained variable is always the first term in cnstr[$i], thus second indx is [0]
	my $constrained_node_name = $cnstr[$i][0]{'var_name'};
	my $constrained_node_ref = $node_list_ref->lookup_by_name($constrained_node_name);
	my $constrained_node_coef = $cnstr[$i][0]{'coef'};
	my $constrained_node_initial_value = $constrained_node_ref->get_initial_value_in_molarity($compartment_volume);

	# name the moiety after that member node which is designated as constrained
	my $moiety_name = "${constrained_node_name}_tot";
	# total concentration of moiety member nodes
	my $moiety_value = $constrained_node_coef * $constrained_node_initial_value;
	# ??? better:  my $constrained_node_expression = "+ $moiety_name";  --> then kill final assignement below !!!
	my $constrained_node_expression;
	print "\n";
	for (my $j=1; $j < @{$cnstr[$i]}; $j++) {
	    my $node_name = $cnstr[$i][$j]{'var_name'};
	    my $node_ref = $node_list_ref->lookup_by_name($node_name);
	    my $node_initial_value = $node_ref->get_initial_value_in_molarity($compartment_volume);
	    my $node_coef = $cnstr[$i][$j]{'coef'};
	    $moiety_value += $node_coef * $node_initial_value;
	    $constrained_node_expression .= ($node_coef == 1) ? " - $cnstr[$i][$j]{'var_name'}" : " - ($cnstr[$i][$j]{'coef'})*$cnstr[$i][$j]{'var_name'}";
	}
	$constrained_node_expression .= (defined $constrained_node_expression) ? " + $moiety_name" : "$moiety_name";

	# this marks constrained node for special treatment when outputing target files
	$node_list_ref->designate_as_constrained($constrained_node_name);

	# create a new variable to store the constrained node expression and store reference in node
	# we can use the same name as node, because it is impossible to have a rate variable of the same name
	# (the BUILD routines of Node/Variable make sure this doesn't happen)
	my $constrained_node_expression_ref = $variable_list_ref->new_variable({
	    name => "$constrained_node_name",
	    value => $constrained_node_expression,
	    type => "constrained_node_expression",
	    is_expression_flag => 1,
	    dimension => "amount/concentration",
	    source_line => "variable created by Moiety.pm",
	});
	$constrained_node_ref->set_nonfree_expression_ref($constrained_node_expression_ref);

	# if not already existing, create new variable to store moiety's value (i.e. total concentration of moiety member nodes)
	# (it can have been created by parser due to specification as bifurcation param)
	my $moiety_ref = $variable_list_ref->lookup_by_name($moiety_name);
	if (!defined $moiety_ref) {
	    # doesn't exists, so create and initialize
	    $moiety_ref = $variable_list_ref->new_variable({
		name => $moiety_name,
 		value => $moiety_value,
		type => "moiety_total",
		is_expression_flag => 0,
		dimension => "amount/concentration",
		source_line => "variable created by Moiety.pm",
	    });
	} else {
	    # was created by parser, so just plug in the value and dimension
	    $moiety_ref->set_value($moiety_value);
	    $moiety_ref->set_dimension("amount/concentration");
	}
	# !!! do we need to quote the expression ???
	print "$constrained_node_name = \"$constrained_node_expression\", $ moiety_name = $moiety_value\n";
    }
    print "\n";
    ### end modify
}


#######################################################################################
# FUNCTIONS
#######################################################################################

### matrix computations

#------------------------#
# Finds left null space #
#------------------------#
sub l_null{
  my @a=@_;
  my ($m,$n)=($#a,$#{ $a[0] });
  my @ident=identity($m);
  my @augm;
  ### augment the stoichiometry matrix with identity
  for my $i (0..$#a){
    my @tmp=@{ $a[$i] };
    push @tmp, @{ $ident[$i] };
    $augm[$i]= [ @tmp ];
  }
  ### reduce the augmented matrix to rref
  my @augmR=rref(@augm);
  ### extract left null space
  my @lNull;
  for my $i (0..$#augmR){
    if (!grep($_ != 0,@{ $augmR[$i] } [0..$n])){ #tolerance
      push @lNull,[ @{ $augmR[$i] } [$n+1..$n+1+$m] ];
    }
  }
  return @lNull;
}

#--------------------------------------
# create idenity matrix.
# Note: argument is size+1
#-----------------------------------
sub identity{
  my $m=shift;
  my @a;
  for my $i (0..$m){
    for my $j (0..$m){
      if($i==$j){$a[$i][$j]=1} else {$a[$i][$j]=0}
    }
  }
  return @a;
}

#---------------------------------------------------
# rref: Computes Reduced Row Echelon Form of matrix.
# Uses a partial pivoting algorthm for stability.
# Functions returns reduced form of argument.
#--------------------------------------------------
sub rref{
  my @a=@_;
  my ($i,$j)=(0,0);
  my ($m,$n)=($#a,$#{ $a[0] });
  while ($i<=$m && $j<=$n){
    my $maxTmp=0;
    my $k=$i;
    ### find leading max
    for (my $q=$i;$q <= $m;$q++){
      if(abs($a[$q][$j])>$maxTmp){
	$maxTmp=abs($a[$q][$j]);
	$k=$q;
      }
    }
     ### end find
   my $tol=0;
    if ($maxTmp<=$tol){# tolerance
      $j++;
    } else {
      ### swap current row with row that contains max
      my @temp=@{ $a[$i] };
      @{ $a[$i] }=@{ $a[$k] };
      @{ $a[$k] }=@temp;
      ### divide pivot row by pivot
      my $pivot=$a[$i][$j];
      @{ $a[$i] }=map($_/$pivot,@{ $a[$i] });
      ### subtract
      my @row=(0..$i-1,$i+1..$m);
      for my $r (@row){
	my $leadingOfRow=$a[$r][$j];
	for my $col ($j..$n){
	  $a[$r][$col]=$a[$r][$col]-$leadingOfRow*$a[$i][$col];
	}
      }
      ### end subtract
      $i++;
      $j++;
    }
  }
  return @a;
}

#--------------------------------
# Print 2d matrices
#--------------------------------
sub print2d{
  my @a=@_;
  for(my $i=0;$i<@a;$i++){
    for(my $j=0;$j<@{$a[$i]};$j++){
      if(length($a[$i][$j])<=1){# ok for -[0-9], but not for two or more digits
	print "  $a[$i][$j]";
      } else {
	print " $a[$i][$j]";
      }
    }
    print "\n"
  }
  print "\n\n";
}

1;  # don't remove -- req'd for module to return true

