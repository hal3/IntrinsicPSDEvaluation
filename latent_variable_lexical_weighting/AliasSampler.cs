using System;

namespace lvlw
{
    public class AliasSampler
    {
        public AliasSampler(double[] d)
        {
            N = d.Length;
            m_cutoffs = new double[N];
            m_aliases = new int[N];
            double[] p = new double[N];
            double sum = 0;
            for (int i = 0; i < N; ++i)
            {
                if (d[i] < 0) throw new Exception("negative density!");
                sum += p[i] = d[i];
            }
            for (int i = 0; i < N; ++i)
                p[i] /= sum;

            // First divide the input values into those that are more likely
            // than a uniform estimate and those that are less likely than a
            // uniform estimate. While we're at it, scale up the probs to be
            // cutoffs on the N individual Bernoulli distributions -- just
            // multiply by N.
            //
            // Use a compact representation -- the first L values are those
            // less likely than uniform, and the next N-L values are above.
            int[] s = new int[N];
            int L;
            {
                int below = 0, above = N - 1;
                for (int i = 0; i < N; ++i)
                {
                    double cutoff = m_cutoffs[i] = N * p[i];
                    if (cutoff >= 1.0) s[above--] = i;
                    else s[below++] = i;
                }
                L = below;
                if (L >= N)
                {
                    for (int i = 0; i < N; ++i)
                    {
                        //Console.WriteLine(p[i]);
                        m_cutoffs[i] = 1.0;
                        m_aliases[i] = i;
                    }
                    return;
                }
            }

            // Now make the aliasing assignments.
            // k is the next index with a cutoff greater than 1.
            int k = s[L];
            int assigned = -1;
            try
            {
            for (assigned = 0; assigned < L; ++assigned)
            {
                // j is the next index with a cutoff less than 1.
                int j = s[assigned];
                // We'll pick j with its currently assigned mass, or k
                // if we draw a uniform above that cutoff.
                m_aliases[j] = k;
                // Steal probability mass from k's bucket to account for
                // the mass delegated as j's alias. k was picked to have
                // cutoff >= 1, so this should always succeed.
                m_cutoffs[k] -= 1.0 - m_cutoffs[j];
                // However, it could be the case that k's bucket has fallen
                // below 1.0 -- shift our donor to the next value if so.
                if (m_cutoffs[k] < 1.0)
                {
                    if (L + 1 == N) break;
                    k = s[++L];
                }
            }
            }
            catch (Exception e)
            {
                Console.WriteLine("problem here");
                Console.WriteLine("assigned = {0}", assigned);
                Console.WriteLine("N = {0}", N);
                Console.WriteLine("L = {0}", L);
                Console.WriteLine("k = {0}", k);
                throw e;
            }
        }
        int N;
        double[] m_cutoffs;
        int[] m_aliases;

        public int Draw(R r)
        {
            int n = r.Sample(N);
            if (r.Uniform() > m_cutoffs[n])
                return m_aliases[n];
            return n;
        }
    }
}

// vim:sw=4:ts=4:et:ai:cindent
