#!/usr/bin/python2.6

from qutils import timer
from math import log
import gurobipy as grb

def constructModel(oldJointData, nonzeroEntries, newEMarginal, newFMarginal, epsilon=1e-6):
    with timer("constr") as tim:
        model = grb.Model("model")

        # construct the variables and the objective
        e2f = {}
        f2e = {}
        newJointVars = {}
        obj = grb.QuadExpr()
        bb = {}
        for e_f in nonzeroEntries.iterkeys():
            (e,f) = e_f
            v = model.addVar(0., 1., 0., grb.GRB.CONTINUOUS, f + '__' + e)
            if not e2f.has_key(e):
                e2f[e] = {}
            if not f2e.has_key(f):
                f2e[f] = {}
            e2f[e][f] = v
            f2e[f][e] = v
            newJointVars[e_f] = v
            if oldJointData.has_key(e_f):
                # objective should contain (v - OLD)^2
                old = oldJointData[e_f]
                b = model.addVar(0., 1., 0., grb.GRB.CONTINUOUS, 'b' + str(e_f))
                obj += (v - old) * (v - old)
                obj += b
                bb[v] = (b,old)
            else:
                # objective should contain v^2
                obj += 1.1 * v
                obj += v * v
        model.update()   # add the variables before setting the objective
        model.setObjective(obj)

        # now create the constraints -- there are E and F marginal
        # constraints of the form:
        #    sum_f newJoint[e,f] = newEMarginal[e]  for all e
        #    sum_e newJoint[e,f] = newFMarginal[f]  for all f
        # this is too restrictive (maybe impossible), so we give
        # a little slack -- maybe this should be penalized in the
        # objective.  anyway, we write:
        #    sum_f newJoint[e,f] - newEMarginal[e] <  epsilon    for all e
        #    sum_f newJoint[e,f] - newEMarginal[e] > -epsilon    for all e
        # and similarly for newFMarginal

        for e,marg in newEMarginal.iteritems():
            lhs = grb.LinExpr(-marg)
            for f,var in e2f[e].iteritems():
                lhs += var
            model.addConstr(lhs <=  epsilon, "ce+" + e)
            model.addConstr(lhs >= -epsilon, "ce-" + e)

        for f,marg in newFMarginal.iteritems():
            lhs = grb.LinExpr(-marg)
            for e,var in f2e[f].iteritems():
                lhs += var
            model.addConstr(lhs <=  epsilon, "cf+" + e)
            model.addConstr(lhs >= -epsilon, "cf-" + e)

        counter = 0
        for v,(b,old) in bb.iteritems():
            model.addConstr(b >=  v - old, "vb+" + str(counter))
            model.addConstr(b >= -v + old, "vb-" + str(counter))
            model.addConstr(b >=  0, "vb0" + str(counter))
            counter += 1

        # finalize the model
        model.update()
        return model

def normalize(d):
    sum = 0
    for p in d.iteritems():
        sum += p[1]
    for p in d.iteritems():
        d[p[0]] = p[1] / float(sum)

def construct(filename):
    oldj = {}
    oj = {}
    newj = {}
    newe = {}
    newf = {}

    with open(filename, 'r') as fh:
        c = 0
        for line in fh:
            c += 1
            if c > 300: break
            pcs = line.split()
            px = pcs[0].split('_')
            f = px[0]
            e = px[2]
            old = int(pcs[1])
            new = int(pcs[2])
            oldj[(e, f)] = old
            oj[pcs[0]] = old
            newj[pcs[0]] = new
            newe[e] = newe.get(e, 0) + new
            newf[f] = newf.get(f, 0) + new

    normalize(oldj)
    normalize(oj)
    normalize(newj)
    normalize(newe)
    normalize(newf)
    nonzeroentries = {}
    for e in newe:
        for f in newf:
            nonzeroentries[(e,f)] = 1
    model = constructModel(oldj, nonzeroentries, newe, newf)

    # verbose output
    with timer("opt") as tim:
        model.params.outputflag = 1
        model.optimize()
        model.printStats()
        model.printQuality()

    # show the final output
    print
    print "==== final variable values ===="
    osum = 0
    nsum = 0
    for var in model.getVars():
        name = var.getAttr(grb.GRB.attr.VarName)
        val = var.getAttr(grb.GRB.attr.X)
        if not name.startswith('b'):
            o = oj.get(name, 1e-9)
            n = newj.get(name, 1e-9)
            val = max(val, 1e-9)
            #if val > 1e-6: print name, "\t", o, '\t', n, '\t', val
            osum += o * log(o / val)
            nsum += n * log(n / val)
    print osum
    print nsum

if __name__ == "__main__":
    #testConstruct()
    construct('pairs.txt')

# vim:sw=4:ts=4:et:ai
