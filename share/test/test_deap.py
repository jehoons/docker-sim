import random
from tqdm import tqdm 
from deap import creator, base, tools, algorithms

import time
import multiprocessing

def evalOneMax(individual):
    time.sleep(1)
    return sum(individual),

if __name__ == "__main__":
    
    creator.create("FitnessMax", base.Fitness, weights=(1.0,))
    creator.create("Individual", list, fitness=creator.FitnessMax)

    toolbox = base.Toolbox()

    toolbox.register("attr_bool", random.randint, 0, 1)
    toolbox.register("individual", tools.initRepeat, creator.Individual, toolbox.attr_bool, n=100)
    toolbox.register("population", tools.initRepeat, list, toolbox.individual)

    toolbox.register("evaluate", evalOneMax)
    toolbox.register("mate", tools.cxTwoPoint)
    toolbox.register("mutate", tools.mutFlipBit, indpb=0.05)
    toolbox.register("select", tools.selTournament, tournsize=3)

    # parallel processing:
    pool = multiprocessing.Pool() 
    toolbox.register("map", pool.map)

    population = toolbox.population(n=50)

    NGEN=50

    for gen in tqdm(range(NGEN)):
        offspring = algorithms.varAnd(population, toolbox, cxpb=0.5, mutpb=0.1)
        fits = toolbox.map(toolbox.evaluate, offspring)
        for fit, ind in zip(fits, offspring):
            ind.fitness.values = fit

        population = toolbox.select(offspring, k=len(population))

    top3 = tools.selBest(population, k=3)

    print('result:')
    print(top3)