######################################################################################
# File:     VariableList.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Template for the creation of new object classes.
######################################################################################
# Detailed Description:
# ---------------------
#
#
######################################################################################

use strict;
use diagnostics;		# equivalent to -w command-line switch
use warnings;

package VariableList;
use Class::Std;
use base qw();
{
    use Carp;
    use Utils;

    use Variable;

    #######################################################################################
    # CLASS ATTRIBUTES
    #######################################################################################

    #######################################################################################
    # ATTRIBUTES
    #######################################################################################
    # maintain list of variables ordered and indexed by ID
    my %variables_of :ATTR(get => 'variables');

    #######################################################################################
    # FUNCTIONS
    #######################################################################################

    #######################################################################################
    # CLASS METHODS
    #######################################################################################

    #######################################################################################
    # INSTANCE METHODS
    #######################################################################################
    #--------------------------------------------------------------------------------------
    # Function: BUILD
    # Synopsys: 
    #--------------------------------------------------------------------------------------
    sub BUILD {
	my ($self, $obj_ID, $arg_ref) = @_;

	$variables_of{$obj_ID} = [];
    }

    sub new_variable {
	my $self = shift;
	my $arg_ref = shift;
	my $obj_ID = ident $self;

	# check that no variable already exists with the same name
	if (defined $self->lookup_by_name($arg_ref->{name})) {
	    print "ERROR: can't create variable $arg_ref->{name} because there already exists one with the same name\n";
	    exit(1);
	}

	$arg_ref->{index} = $self->get_count();

	my $variable_ref = Variable->new($arg_ref);

	push @{$variables_of{$obj_ID}}, $variable_ref;

	return $variable_ref;
    }
    
    # class methods
    sub get_list {
	my $self = shift;
	return @{$variables_of{ident $self}};
    }

    sub get_count {
	my $self = shift;
	return (@{$variables_of{ident $self}} + 0);
    }

    sub get_names {
	my $self = shift;
	my @names = map($_->get_name(), @{$variables_of{ident $self}});
	return @names;
    }

    # returns object handle
    sub lookup_by_name {
	my $self = shift;
	my $name = shift;
	my $obj_ID = ident $self;

	for (my $i=0; $i < @{$variables_of{$obj_ID}}; $i++) {
	    if ($variables_of{$obj_ID}[$i]->get_name() eq $name) {
		return $variables_of{$obj_ID}[$i];
	    }
	}
	return undef;
    }

    # this function updates the index attribute of all variables
    # to match their position in variables list
    sub refresh_indices {
	my $self = shift;
	my $obj_ID = ident $self;

	for (my $i=0; $i < @{$variables_of{$obj_ID}}; $i++) {
	    my $variable_ref = $variables_of{$obj_ID}[$i];
	    $variable_ref->set_index($i);
	}
    }

    #----------------------------------------------------------------------#
    # re-order the variable list so each expression is a function of       #
    # previously defined variables                                         #
    #----------------------------------------------------------------------#
    sub reorder_variable_list {
	my $self = shift;
	my $obj_ID = ident $self;

	my @variables = @{$variables_of{$obj_ID}};
	my @variable_names = $self->get_names();

	for (my $i=0; $i < @variable_names; $i++) {
	    my $variable_ref = lookup_by_name($variable_names[$i]);
	    my $variable_name = $variable_ref->get_name();
	    my $variable_value = $variable_ref->get_value();
	    my $is_expression_flag = $variable_ref->get_is_expression_flag();
	    if ($is_expression_flag == 1){ # if variable is an expression
		my @split_names=split(/\+|\-|\*|\/|\(|\)/,$variable_value); # split it
		foreach my $name (@split_names) {
		    # test if any split part of expression matches any entry in list of variables
		    if(grep($name eq $_, @variable_names[$i+1..$#variable_names])){
			# if it matches, reorder @variables and @variable_names
			push(@variable_names,$variable_names[$i]);
			splice(@variable_names,$i,1);
			push(@variables,$variables[$i]);
			splice(@variables,$i,1);
			$i--; # needed so that next iteration doesn't skip over variable
			last;
		    }
		}
	    }
	}

	# store reordered list
	@{$variables_of{$obj_ID}} = @variables;

	# update index attribute given reordering occurred
	$self->refresh_indices();
    }

}


sub run_testcases {

    print "Testing class: VariableList\n";
    my $list_ref = VariableList->new({});
    
    print "Creating var1 object: ";
    my $var1_ref = $list_ref->new_variable({
       name => "f1",
       index => 0,
       value => 1.0,
       type => "rate",
       dimension => 2,
       is_expression_flag => 0,
       source_line => "f1=1.0",
      });
    print $var1_ref->_DUMP();
    print "instance count is ".$list_ref->get_count()."\n";

    print "Creating var2 object: ";
    my $var2_ref = $list_ref->new_variable({
       name => "f2",
       index => 1,
       value => 1.1,
       type => "rate",
       dimension => 1,
       is_expression_flag => 1,
       source_line => "f2=1.1",
      });

    print $var2_ref->_DUMP();
    print "instance count is ".$list_ref->get_count()."\n";

    print "Creating var3 object: ";
    my $var3_ref = $list_ref->new_variable({
       name => "f3",
       index => 2,
       value => 1.5,
       type => "rate",
       dimension => 3,
       is_expression_flag => 0,
       source_line => "f3=1.5",
      });

    print $var3_ref->_DUMP();
    print "instance count is ".$list_ref->get_count()."\n";

    print "iterating through variable list...\n";
    foreach my $var_ref ($list_ref->get_list()) {
	print "variable ".$var_ref->get_name()." --> ". $var_ref->get_source_line()."\n"; 
    }

    print "testing get_names():\n";
    my @names = $list_ref->get_names();
    print join ",", @names ."\n";

    print "testing lookup_by_name():\n";

    my $lookup_result_ref = $list_ref->lookup_by_name("f3");
    if (defined $lookup_result_ref) {
	print "variable exists and has value ". $list_ref->lookup_by_name("f3")->get_value() ."\n";
    }
    print $lookup_result_ref->_DUMP();

    $lookup_result_ref = $list_ref->lookup_by_name("doesntexist");
    if (!defined $lookup_result_ref) {
	print "variable does not exist\n";
    }
    print "Done testing class: VariableList\n";


}


# Package BEGIN must return true value
return 1;

