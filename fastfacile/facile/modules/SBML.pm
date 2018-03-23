###############################################################################
# File:     SBML.pm
#
# Copyright (C) 2005-2011 Ollivier, Siso-Nadal, Swain et al.
#
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it
# under certain conditions. See file LICENSE.TXT for details.
#
# Synopsys: Export model in SBML format.
##############################################################################
# Detailed Description:
# ---------------------
#
# Uses libSBML v4.3 library to generate SBML file.
#
#
# Refs:
#   http://sbml.org/Software/libSBML/docs/perl-api
#   http://sbml.org/Software/libSBML/docs/cpp-api/libsbml-example.html
#
###############################################################################

package SBML;

use strict;
use diagnostics;          # equivalent to -w command-line switch
use warnings;

use vars qw(@ISA @EXPORT);

require Exporter;
@ISA = qw(Exporter);

# these subroutines are imported when you use XPP.pm
@EXPORT = qw(
	     export_sbml
	    );

#use Globals;

# flag indicating presence of LibSBML
use vars qw($libSBML_unavailable);

# imports LibSBML into current package if present
BEGIN {
    eval "use LibSBML";
    if ($@ eq "") {
	# successful import of LibSBML\n";
	$libSBML_unavailable = 0;
    } else {
	# couldn't load libSBML -- SBML export will be unavailable
        $libSBML_unavailable = 1;
######	print $@;   # print out error returned by eval()
    }
}

#######################################################################################
# INSTANCE METHODS
#######################################################################################

# See http://sbml.org/Software/libSBML/docs/cpp-api/libsbml-example.html
# for tutorial on how to create SBML model
sub export_sbml {
    my $self = shift;
    my $model_name = shift;

    # check library
    if ($libSBML_unavailable) {
        print "ERROR: couldn't load LibSBML module -- SBML export is unavailable (don't use -S switch)\n";
	print "To debug the problem, try the command 'perl -MLibSBML' and resolve any problems reported\n";
        exit(1);
    }

    my $reaction_list_ref = $self->get_reaction_list();
    my $node_list_ref = $self->get_node_list();
    my $variable_list_ref = $self->get_variable_list();

    my $compartment_volume = $self->get_config_ref()->{compartment_volume};

    # Create model for SBML level 2, version 4
    my $SBML_level = 2;
    my $SBML_version = 4;
    my $document = LibSBML::SBMLDocument->new($SBML_level, $SBML_version);

    my $model = $document->createModel();
    $model->setId($model_name);

    # UnitDefinition object for "per_second".
#    my $unitdef = $model->createUnitDefinition();
#    $unitdef->setId("per_second");
#    my $unit = $unitdef->createUnit();
#    $unit->setKind(LibSBML::UnitKind_forName("second"));
#    $unit->setExponent(-1);
#    # UnitDefinition object for "litre_per_mole_per_second".
#    $unitdef = $model->createUnitDefinition();
#    $unitdef->setId("litre_per_mole_per_second");   # is this right ??
#    $unit = $unitdef->createUnit();
#    $unit->setKind(LibSBML::UnitKind_forName("mole"));
#    $unit->setExponent(-1);
#    $unit = $unitdef->createUnit();
#    $unit->setKind(LibSBML::UnitKind_forName("litre"));
#    $unit->setExponent(1);
#    $unit = $unitdef->createUnit();
#    $unit->setKind(LibSBML::UnitKind_forName("second"));
#    $unit->setExponent(-1);

# !!! once units are defined, need to assign units to the param defns below
# !!! in SBML lvl 3, can define units at the model level, but v3 is likely not well supported

    my $compartment = $model->createCompartment();
    $compartment->setId("main");

    foreach my $node_ref ($node_list_ref->get_list()) {
	my $species = $model->createSpecies();
	$species->setId($node_ref->get_name());
	$species->setInitialAmount($node_ref->get_initial_value_in_molarity($compartment_volume));
	$species->setCompartment("main");
    }

    # create global parameters for all variables
    foreach my $variable_ref ($variable_list_ref->get_list()) {
	if ($variable_ref->get_is_expression_flag() == 0) {
	    # set value to the constant
	    my $parameter = $model->createParameter();
	    $parameter->setId($variable_ref->get_name());
	    $parameter->setValue($variable_ref->get_value());
	} else {
	    # create assignment rule
	    my $parameter = $model->createParameter();
	    $parameter->setId($variable_ref->get_name());
	    $parameter->setConstant(0);
	    my $assignment_rule = $model->createAssignmentRule();
	    $assignment_rule->setVariable($variable_ref->get_name());
	    $assignment_rule->setFormula($variable_ref->get_value());
	}
    }

    foreach my $reaction_ref ($reaction_list_ref->get_list()) {
	my $reaction = $model->createReaction();
	$reaction->setId("R".$reaction_ref->get_index());
	$reaction->setName($reaction_ref->get_source_line());
	foreach my $substrate_name (@{$reaction_ref->get_substrate_names_ref()}) {
	    my $species_reference = $reaction->createReactant();
	    $species_reference->setSpecies($substrate_name);
	}
	foreach my $product_name (@{$reaction_ref->get_product_names_ref()}) {
	    my $species_reference = $reaction->createProduct();
	    $species_reference->setSpecies($product_name);
	}	
	my $kinetic_law = $reaction->createKineticLaw();
	$kinetic_law->setFormula($reaction_ref->get_velocity());
    }

    my $num_internal_problems = $document->checkInternalConsistency();
    if ($num_internal_problems) {
      print "WARNING: SBML internal consistency check reports the following $num_internal_problems problems ".$document->getNumErrors()."\n";
      $document->printErrors();
    }

    # this generates a bunch of warnings about units...
#    my $num_problems = $document->checkConsistency();
#    print "Errors: ($num_problems)".$document->getNumErrors()."\n";
#    $document->printErrors();

    my $writer = LibSBML::SBMLWriter->new();
    return $writer->writeToString($document);
}


sub run_testcase {

  # Create model for SBML level 2, version 4
  my $SBML_level = 2;
  my $SBML_version = 4;
  my $document = LibSBML::SBMLDocument->new($SBML_level, $SBML_version);

  my $model = $document->createModel();
  $model->setId("test_model");

  my $species = $model->createSpecies();
  $species->setId("A");

  my $writer = LibSBML::SBMLWriter->new();
  print $writer->writeToString($document);
}

1;  # don't remove -- req'd for module to return true

