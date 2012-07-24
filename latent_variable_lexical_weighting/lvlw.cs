using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;

namespace lvlw
{
    class Program
    {
        static void Main(string[] args)
        {
            var r = new R();
            var wa = Utils.Alignments(args[0], args[1], args[2]);
            Model m = new Model(wa, 1, r);
            m.Sweep(r);
            for (int s = 1; s <= 3; ++s)
            {
                m.Split(r);
                for (int i = 1; i <= 15; ++i)
                {
                    m.Sweep(r);
                    Console.Out.Write(".");
                    Console.Out.Flush();
                }
                Console.Out.WriteLine();
                m.DumpAssign();
            }
            m.Write(args[3]);
        }
    }

    public class Model
    {
        public Model(IEnumerable<WordAlignment> e, int k, R r)
        {
            K = k;
            E = new Vocab();
            F = new Vocab();
            D = new List<Document>();
            foreach (var wa in e)
            {
                var doc = new Document();
                doc.Theta = r.SampleDenseCategorical(k);
                doc.E = new List<int>();
                doc.F = new List<int>();
                doc.Z = new List<int>();
                foreach (var asn in wa.A)
                {
                    doc.F.Add(F[wa.S[asn.Item1]]);
                    doc.E.Add(E[wa.T[asn.Item2]]);
                    doc.Z.Add(r.Sample(k));
                }
                D.Add(doc);
            }
            SampleDists(r);
            //DumpAssign();

        }

        public void Write(string filename)
        {
            using (var sw = new StreamWriter(filename))
            {
                Write(sw);
            }
        }

        private void Write(TextWriter sw)
        {
            foreach (var d in D)
            {
                foreach (var pz in d.Theta)
                    sw.Write("{0:0.000}\t", pz);
                sw.WriteLine();
            }
            sw.WriteLine();
            for (int k = 0; k < K; ++k)
            {
                sw.Write("{0}", k);
                var dist = Alpha[k];
                WriteDist(sw, dist, F);
                sw.WriteLine();
            }
            sw.WriteLine();
            foreach (var g in Beta.GroupBy(x => x.Key.Item2).OrderBy(x => x.Key))
            {
                foreach (var p in g.OrderBy(x => x.Key.Item1))
                {
                    sw.Write("{0}_{1}", F[p.Key.Item2], p.Key.Item1);
                    WriteDist(sw, p.Value, E);
                    sw.WriteLine();
                }
            }
        }

        private static void WriteDist(TextWriter sw, SparseCategorical dist, Vocab v)
        {
            foreach (var p in dist.W.OrderByDescending(kvp => kvp.Value))
                sw.Write("\t{0}={1}", v[p.Key], p.Value);
        }

        public void DumpAssign()
        {
            foreach (var d in D)
            {
                for (int i = 0; i < K; ++i)
                    Console.Write("{0:0.000}\t", d.Theta[i]);
                Console.WriteLine();
                for (int i = 0; i < d.E.Count; ++i)
                    Console.WriteLine("{0,4}: {1,20} -> {2,20}", d.Z[i], F[d.F[i]], E[d.E[i]]);
                Console.WriteLine("...");
            }
            Console.WriteLine("===========");
        }

        public void Sweep(R r)
        {
            SampleZ(r);
            SampleDists(r);
        }

        public void Split(R r)
        {
            foreach (var d in D)
            {
                for (int i = 0; i < d.Z.Count; ++i)
                    if (r.Sample(2) == 0)
                        d.Z[i] += K;
                var t = d.Theta;
                d.Theta = new double[K * 2];
                for (int k = 0; k < K; ++k)
                {
                    var salt = r.Uniform() * 2 - 1;
                    var mix = 0.5;
                    salt *= 0.1;
                    d.Theta[k] = t[k] * (mix + salt);
                    d.Theta[K + k] = t[k] * (mix - salt);
                }
            }
            K *= 2;
            SampleDists(r);
        }

        public void SampleDists(R r)
        {
            var cAlpha = new Counter<int>[K];
            for (int i = 0; i < K; ++i) cAlpha[i] = new Counter<int>();
            var cBeta = new AutoInitDict<Tuple<int, int>, Counter<int>>(() => new Counter<int>());
            int count = 0;
            foreach (var d in D)
            {
                double[] cTheta = new double[K];
                for (int i = 0; i < K; ++i)
                    cTheta[i] = 0.01;
                for (int i = 0; i < d.E.Count; ++i)
                {
                    ++cTheta[d.Z[i]];
                    cAlpha[d.Z[i]].Inc(d.F[i]);
                    cBeta[T(d.Z[i], d.F[i])].Inc(d.E[i]);
                }
                /*
                if (count == 0)
                {
                    Console.Write("theta\t");
                    for (int i = 0; i < K; ++i)
                        Console.Write("{0:0.000}\t",d.Theta[i]);
                    Console.WriteLine();
                    Console.Write("c\t");
                    for (int i = 0; i < K; ++i)
                        Console.Write("{0:0.000}\t",cTheta[i]);
                    Console.WriteLine();
                }
                */
                ++count;
                d.Theta = r.SampleDirichlet(cTheta);
            }
            Alpha = new SparseCategorical[K];
            for (int k = 0; k < K; ++k)
                Alpha[k] = r.SampleSparseCategorical(cAlpha[k], 0.01, 1e-3);
            Beta = new Dictionary<Tuple<int,int>,SparseCategorical>();
            foreach (var p in cBeta)
                Beta[p.Key] = r.SampleSparseCategorical(p.Value, 0.01, 1e-3);
            //Write(Console.Out);
        }

        public void SampleZ(R r)
        {
            double[] density = new double[K];
            foreach (var d in D)
            {
                var theta = d.Theta;
                for (int i = 0; i < d.Z.Count; ++i)
                {
                    Array.Copy(theta, density, K);
                    for (int k = 0; k < K; ++k)
                    {
                        try
                        {
                            density[k] *= Alpha[k].W[d.F[i]] * Beta[T(k, d.F[i])].W[d.E[i]];
                        }
                        catch (Exception)
                        {
                            density[k] = 0;
                        }
                        density[k] += 0.0001;
                    }
                    d.Z[i] = r.SampleFromCategorical(density);
                }
            }
            //DumpAssign();
        }

        public static Tuple<int, int> T(int i1, int i2) { return new Tuple<int, int>(i1, i2); }

        public Vocab E;
        public Vocab F;
        public int K;
        public List<Document> D;
        public SparseCategorical[] Alpha;
        public Dictionary<Tuple<int, int>, SparseCategorical> Beta;
    }

    public class Document
    {
        public double[] Theta;
        public List<int> Z, F, E;
    }

    public class SparseCategorical
    {
        public Dictionary<int, double> W = new Dictionary<int, double>();
    }
}

// vim:sw=4:ts=4:et:ai:cindent
