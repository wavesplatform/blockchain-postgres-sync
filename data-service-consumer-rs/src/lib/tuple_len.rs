pub trait TupleLen {
    fn len(&self) -> usize;
}

macro_rules! count {
    () => (0usize);
    ( $x:tt $($xs:tt)* ) => (1usize + count!($($xs)*));
}

macro_rules! tuple_len_impls {
    ($(
        ($($T:ident),+)
    )+) => {
        $(
            impl<$($T),+> TupleLen for ($($T,)+) {
                #[inline]
                fn len(&self) -> usize {
                    count!($($T)+)
                }
            }
        )+
    }
}

tuple_len_impls! {
    (A)
    (A, B)
    (A, B, C)
    (A, B, C, D)
    (A, B, C, D, E)
    (A, B, C, D, E, F)
    (A, B, C, D, E, F, G)
    (A, B, C, D, E, F, G, H)
    (A, B, C, D, E, F, G, H, I)
    (A, B, C, D, E, F, G, H, I, J)
    (A, B, C, D, E, F, G, H, I, J, K)
    (A, B, C, D, E, F, G, H, I, J, K, L)
    (A, B, C, D, E, F, G, H, I, J, K, L, M)
    (A, B, C, D, E, F, G, H, I, J, K, L, M, N)
    (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O)
    (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P)
    (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q)
    (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R)
    (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S)
    (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T)
    (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U)
    (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V)
    (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W)
    (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X)
    (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y)
    (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z)
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
