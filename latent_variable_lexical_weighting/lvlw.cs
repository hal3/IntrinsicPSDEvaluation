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
            m.Split(r);
            for (int i = 1; i <= 5; ++i)
                m.Sweep(r);
            m.Write(args[3]);
        }
    }

    public class R
    {
        Random m_r = new Random(1);
        public double[] SampleDenseCategorical(int k)
        {
            double[] w = new double[k];
            double sum = 0;
            for (int i = 0; i < k; ++i)
                sum += w[i] = m_r.NextDouble();
            for (int i = 0; i < k; ++i)
                w[i] /= sum;
            return w;
        }
        public int SampleFromCategorical(double[] rgd)
        {
            double sum = 0;
            for (int i = 0; i < rgd.Length; ++i)
                sum += rgd[i];
            double val = m_r.NextDouble() * sum;
            for (int i = 0; i < rgd.Length - 1; ++i)
            {
                var x = rgd[i];
                if (val <= x) return i;
                val -= x;
            }
            return rgd.Length - 1;
        }
        public int Sample(int k)
        {
            return m_r.Next(0, k);
        }
        public double[] SampleDenseCategorical(Counter<int> c)
        {
            var dim = c.Keys.Max() + 1;
            double[] rgd = new double[dim];
            double sum = c.Values.Sum();
            foreach (var p in c)
                rgd[p.Key] = p.Value / sum;
            return rgd;
        }
        public double[] SampleDenseCategorical(int[] c)
        {
            double[] rgd = new double[c.Length];
            for (int i = 0; i < c.Length; ++i)
                rgd[i] = c[i] + Uniform();
            double sum = rgd.Sum();
            for (int i = 0; i < c.Length; ++i)
                rgd[i] /= sum;
            return rgd;
        }

        public SparseCategorical SampleSparseCategorical(Counter<int> c)
        {
            var sc = new SparseCategorical();
            double sum = c.Values.Sum();
            foreach (var p in c)
                sc.W[p.Key] = p.Value / sum;
            return sc;
        }

        public double Uniform()
        {
            return m_r.NextDouble();
        }
    }

    public class Vocab
    {
        public int this[string s]
        {
            get
            {
                int id;
                if (m_map.TryGetValue(s, out id)) return id;
                id = m_array.Count;
                m_array.Add(s);
                m_map[s] = id;
                return id;
            }
        }

        public string this[int id]
        {
            get
            {
                if (id < 0 || id >= m_array.Count)
                    throw new Exception("out of range vocab id");
                return m_array[id];
            }
        }

        Dictionary<string, int> m_map = new Dictionary<string, int>();
        List<string> m_array = new List<string>();
    }

    public class AutoInitDict<K, V> : Dictionary<K, V>
    {
        public AutoInitDict(Func<V> c)
        {
            creator = c;
        }

        Func<V> creator;

        public new V this[K key]
        {
            get
            {
                V v;
                if (!TryGetValue(key, out v))
                {
                    this.Add(key, v = creator());
                }
                return v;
            }
        }
    }

    public class Counter<T> : Dictionary<T, int>
    {
        public int Inc(T t) { return Inc(t, 1); }
        public int Dec(T t) { return Inc(t, -1); }
        public int Inc(T t, int delta)
        {
            int val;
            if (!TryGetValue(t, out val))
                val = 0;
            val += delta;
            if (val == 0)
                Remove(t);
            else
                this[t] = val;
            return val;
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
            DumpAssign();

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
            for (int k = 0; k < K; ++k)
            {
                sw.Write("{0}", k);
                var dist = Alpha[k];
                WriteDist(sw, dist, F);
                sw.WriteLine();
            }
            sw.WriteLine();
            foreach (var p in Beta)
            {
                sw.Write("{0}_{1}", F[p.Key.Item2], p.Key.Item1);
                WriteDist(sw, p.Value, E);
                sw.WriteLine();
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
            foreach (var d in D)
            {
                int[] cTheta = new int[K];
                for (int i = 0; i < d.E.Count; ++i)
                {
                    ++cTheta[d.Z[i]];
                    cAlpha[d.Z[i]].Inc(d.F[i]);
                    cBeta[T(d.Z[i], d.F[i])].Inc(d.E[i]);
                }
                d.Theta = r.SampleDenseCategorical(cTheta);
            }
            Alpha = new SparseCategorical[K];
            for (int k = 0; k < K; ++k)
                Alpha[k] = r.SampleSparseCategorical(cAlpha[k]);
            Beta = new Dictionary<Tuple<int,int>,SparseCategorical>();
            foreach (var p in cBeta)
                Beta[p.Key] = r.SampleSparseCategorical(p.Value);
            Write(Console.Out);
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
                        density[k] += 0.1;
                    }
                    d.Z[i] = r.SampleFromCategorical(density);
                }
            }
            DumpAssign();
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


    public class Utils
    {
        public static IEnumerable<List<T>> Transpose<T>(params IEnumerable<T>[] e)
        {
            var le = new List<IEnumerator<T>>(e.Select(x => x.GetEnumerator()));
            while (le.All(x => x.MoveNext()))
                yield return new List<T>(le.Select(x => x.Current));
        }

        public static IEnumerable<WordAlignment> Alignments(string s, string t, string a)
        {
            foreach (var l in Transpose(GetLines(s), GetLines(t), GetLines(a)))
            {
                yield return new WordAlignment(l[0], l[1], l[2]);
            }
        }

        public static IEnumerable<string> GetLines(string filename)
        {
            using (var sr = new StreamReader(filename))
            {
                string line;
                while (null != (line = sr.ReadLine()))
                    yield return line;
            }
        }
    }

    public class WordAlignment
    {
        public static Tuple<int, int> ParsePair(string s)
        {
            var x = s.Split('-');
            return new Tuple<int, int>(int.Parse(x[0]), int.Parse(x[1]));
        }
        public WordAlignment(string s, string t, string a)
        {
            Parse(s, t, a);
        }

        private void Parse(string s, string t, string a)
        {
            S = new List<string>(s.Split(' '));
            T = new List<string>(t.Split(' '));
            A = new List<Tuple<int, int>>(a.Split(' ').Select(ParsePair));
        }
        public List<string> S, T;
        public List<Tuple<int, int>> A;
    }
}
