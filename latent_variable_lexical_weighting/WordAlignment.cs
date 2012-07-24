using System;
using System.Collections.Generic;
using System.Linq;

namespace lvlw
{
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
            S = new List<string>(s.ToLower().Split(' '));
            T = new List<string>(t.ToLower().Split(' '));
            A = new List<Tuple<int, int>>(a.Split(' ').Select(ParsePair));
        }
        public List<string> S, T;
        public List<Tuple<int, int>> A;
    }
}
