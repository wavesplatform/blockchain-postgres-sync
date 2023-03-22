pub trait TupleLen {
    fn len(&self) -> usize;
}

macro_rules! count {
    () => (0);
    ( $x:tt $($xs:tt)* ) => (1 + count!($($xs)*));
}

macro_rules! tuple_len_impls {
    ( $T:ident, $($rem:ident),+ ) => {
        impl<$T, $($rem),+> TupleLen for ($T, $($rem),+) {
            #[inline]
            fn len(&self) -> usize {
                count!($T $($rem)+)
            }
        }

        tuple_len_impls!($($rem),+);
    };
    ( $T:ident ) => {
        impl<$T> TupleLen for ($T,) {
            #[inline]
            fn len(&self) -> usize {
                1
            }
        }
    };
}

// this macro makes TupleLen impls for (A, ..., Z), (B, ..., Z), ..., (Y, Z), (Z,)
tuple_len_impls! {
    A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z
}

#[cfg(test)]
mod tests {
    use super::TupleLen;

    #[test]
    fn tuple_len() {
        assert_eq!((1,).len(), 1);
        assert_eq!((1, 2,).len(), 2);
        assert_eq!((1, 2, 3,).len(), 3);
        assert_eq!((1, 2, 3, 4,).len(), 4);
    }
}
