using System;
using System.Collections.Generic;

namespace lvlw
{
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
}
