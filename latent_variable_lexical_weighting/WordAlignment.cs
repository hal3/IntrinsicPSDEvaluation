using System;
using System.Collections.Generic;
using System.Linq;

namespace lvlw
{
    public class WordAlignment
    {
        public static Pair<int, int> ParsePair(string s)
        {
            var x = s.Split('-');
            return new Pair<int, int>(int.Parse(x[0]), int.Parse(x[1]));
        }
        public WordAlignment(string s, string t, string a)
        {
            Parse(s, t, a);
        }

        private void Parse(string s, string t, string a)
        {
            try
            {
                S = new List<string>(s.ToLower().Split(' '));
                T = new List<string>(t.ToLower().Split(' '));
                if (a.Trim().Length == 0)
                    A = new List<Pair<int, int>>();
                else
                    A = new List<Pair<int, int>>(a.Split(' ').Select((Func<string, Pair<int, int>>)ParsePair));
            }
            catch (Exception)
            {
                Console.WriteLine("Failed to parse");
                Console.WriteLine(s);
                Console.WriteLine(t);
                Console.WriteLine(a);
                S = new List<string>();
                T = new List<string>();
                A = new List<Pair<int, int>>();
            }
        }
        public List<string> S, T;
        public List<Pair<int, int>> A;
    }
}

// vim:sw=4:ts=4:et:ai:cindent
