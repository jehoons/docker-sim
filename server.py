import zerorpc
import libsbml
import roadrunner
import libsbml2matlab
import sys

if __name__ == "__main__":
    if len(sys.argv) > 1:
        port = sys.argv[1]

class SbmlRPC(object):
    def __init__(self):
        self.nameSpace = {}
    def clearNameSpace(self, id):
        del self.nameSpace[id]
    def getLibSBMLVersionString(self):
        return libsbml.getLibSBMLVersionString()
    def createModel(self, params, id):
        self.nameSpace[id] = {};
        self.nameSpace[id]['doc'] = libsbml.SBMLDocument(params['level'], params['version'])
        self.nameSpace[id]['model'] = self.nameSpace[id]['doc'].createModel()
        self.nameSpace[id]['model'].setId(str(params['id']))
        self.nameSpace[id]['model'].setName(str(params['name']))
    def loadModel(self, params, id):
        # Initializing name space
        self.nameSpace[id] = {};
        sbml = str(params['sbml'])
        self.saveModel(sbml, id)
        self.rr = roadrunner.RoadRunner()
        doc = self.doc
        rr = self.rr
        rr.load(libsbml.writeSBMLToString(doc))
        return True
    def saveModel(self, sbml, id):
        doc = libsbml.readSBMLFromString(sbml)
        self.doc = doc
        self.model = doc.getModel()
    def getModel(self, params, id):
        return libsbml.writeSBMLToString(self.doc)
    def getModelName(self, params, id):
        return self.model.getName()
    def getMatlab(self, params, id):
        doc = self.doc
        try:
            matlab = libsbml2matlab.sbml2matlab(libsbml.writeSBMLToString(doc))
        except Exception:
            matlab = 'Sorry, could not translate to MATLAB :('
        return matlab
    def getModelId(self, params, id):
        return self.model.getId()
    def getCompartments(self, params, id):
        compartmentList = self.model.getListOfCompartments()
        result = []
        for compartment in compartmentList:
            result.append({
                'id': compartment.getId(),
                'name': compartment.getName(),
                'size': compartment.getSize()
            })
        return result
    def getSpecies(self, params, id):
        speciesList = self.model.getListOfSpecies()
        result = []
        for species in speciesList:
            result.append({
                'id': species.getId(),
                'name': species.getName(),
                'initialAmount': species.getInitialAmount()
            })
        return result
    def getReactions(self, params, id):
        reactionList = self.model.getListOfReactions()
        result = []
        for reaction in reactionList:
            products = []
            for product in reaction.getListOfProducts():
                products.append(product.getSpecies())
            reactants = []
            for reactant in reaction.getListOfReactants():
                reactants.append(reactant.getSpecies())
            kineticLawObj = reaction.getKineticLaw()
            if kineticLawObj is not None:
                if kineticLawObj.isSetMath():
                    kineticLaw = libsbml.formulaToString(kineticLawObj.getMath())
            else:
                kineticLaw = ''
            result.append({
                'id': reaction.getId(),
                'name': reaction.getName(),
                'products': products,
                'reactants': reactants,
                'kineticLaw': kineticLaw
            })
        return result
    def updateReaction(self, params, id):
        reaction = self.model.getReaction(str(params['id']))
        if reaction is None:
            return
        changes = params['changes']
        if 'id' in changes:
            reaction.setId(str(changes['id']))
        if 'name' in changes:
            reaction.setName(str(changes['name']))
        if 'kineticLaw' in changes:
            kLaw = reaction.getKineticLaw()
            if kLaw is None:
                kLaw = reaction.createKineticLaw()
            kLaw.setFormula(str(changes['kineticLaw']))
        if 'species' in changes:
            for specie in changes['species']:
                reaction.removeReactant(str(specie['id']))
                reaction.removeProduct(str(specie['id']))
                if specie['reactant']:
                    reactant = reaction.createReactant()
                    reactant.setSpecies(str(specie['id']))
                    reactant.setConstant(False) # L3V1
                else:
                    reaction.removeReactant(str(specie['id']))
                if specie['product']:
                    product = reaction.createProduct()
                    product.setSpecies(str(specie['id']))
                    product.setConstant(False) # L3V1
                else:
                    reaction.removeProduct(str(specie['id']))
        return True

    #def create(self, params, id):
    #    func = getattr(model, 'create' + str(params['element']))
    #    element = func()
    #    self.set(params, id)
    #def set(self, params, id):
    #    func = getattr()
    def addSpecies(self, params, id):
        sp = self.model.createSpecies()
        if 'id' in params:
            sp.setId(str(params['id']))
        if 'name' in params:
            sp.setName(str(params['name']))
        if 'compartment' in params:
            sp.setCompartment(str(params['compartment']))
        if 'initialAmount' in params:
            sp.setInitialAmount(float(params['initialAmount']))
        sp.setHasOnlySubstanceUnits(True)
        sp.setBoundaryCondition(False)
        sp.setConstant(False)
    def updateSpecies(self, params, id):
        sp = self.model.getSpecies(str(params['id']))
        changes = params['changes']
        if 'id' in changes:
            sp.setId(str(changes['id']))
        if 'name' in changes:
            sp.setName(str(changes['name']))
        if 'compartment' in changes:
            sp.setCompartment(str(changes['compartment']))
        if 'initialAmount' in changes:
            sp.setInitialAmount(float(changes['initialAmount']))
    def addCompartment(self, params, id):
        comp = self.model.createCompartment()
        if 'id' in params:
            comp.setId(str(params['id']))
        if 'size' in params:
            comp.setSize(params['size'])
        if 'constant' in params:
            comp.setConstant(params['constant'])
    def addReaction(self, params, id):
        reaction = self.model.createReaction()
        if 'id' in params:
            reaction.setId(str(params['id']))
        if 'reactants' in params:
            for speciesId in params['reactants']:
                reactant = reaction.createReactant()
                reactant.setSpecies(str(speciesId))
        if 'products' in params:
            for speciesId in params['products']:
                product = reaction.createProduct()
                product.setSpecies(str(speciesId))
        # stuff to satisfy L3V1 for now
        reaction.setReversible(False)
        reaction.setFast(False)
    def addParameter(self, params, id):
        parameter = self.model.createParameter()
        parameter.setId(str(params['id']))
        parameter.setValue(float(params['value']))
    def simulate(self, params, id):
        rr = self.rr
        rr.reset()
        return rr.simulate(params['timeStart'], params['timeEnd'], params['numPoints'])
    def getParameterIds(self, params, id):
        rr = self.rr
        return rr.model.getGlobalParameterIds()
    def getParameters(self, params, id):
        rr = self.rr
        ids = rr.model.getGlobalParameterIds()
        values = rr.model.getGlobalParameterValues()
        return {'ids': ids, 'values': values}
    def setParameterValueById(self, params, id):
        rr = self.rr
        rr.model[params['id']] = float(params['value'])
        rr.reset()
        self.saveModel(rr.getCurrentSBML(), id)
    def getId(self):
        return self.model.getId()
    def libsbmlRun(self, method, *params):
        func = getattr(libsbml, method)
        return func(*params)
    def modelRun(self, method, *params):
        func = getattr(self.model, method)
        return func(*params)

s = zerorpc.Server(SbmlRPC())
try:
    port
except NameError:
    print "Port was not defined"
else:
    print "Running zerorpc on Port: " + port
    s.bind("tcp://0.0.0.0:" + port)
    s.run()
