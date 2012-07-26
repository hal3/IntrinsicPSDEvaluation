using System;

public class Pair<T1, T2>
{
    public T1 Item1;
    public T2 Item2;

    public Pair() { Item1 = default(T1); Item2 = default(T2); }
    public Pair(T1 t1, T2 t2) { Item1 = t1; Item2 = t2; }

    public override int GetHashCode()
    {
        return Item1.GetHashCode() * 37 + Item2.GetHashCode();
    }

    public override bool Equals(object o)
    {
        if (!(o is Pair<T1, T2>)) return false;
        Pair<T1, T2> p = (Pair<T1, T2>)o;
        return Item1.Equals(p.Item1) && Item2.Equals(p.Item2);
    }
}
// vim:sw=4:ts=4:et:ai:cindent
