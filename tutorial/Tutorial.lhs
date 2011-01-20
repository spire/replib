Programming with binders using RepLib
=====================================

*Names* are the bane of every language implementation: they play an
unavoidable, central role, yet are tedious to deal with and surprisingly
tricky to get right.  XXX sign errors

RepLib includes a flexible and powerful library for programming with
names and binders, which makes programming with binders easy and
painless.  Built on top of RepLib's generic programming framework, it
does a lot of work behind the scenes to provide you with a seamless,
"it just works" experience.

This literate Haskell tutorial will walk you through the basics of
using the library.

The untyped lambda calculus
---------------------------

Let's start by writing a simple untyped lambda calculus
interpreter. This will illustrate the basic functionality of the
binding library.

**Preliminaries**

First, we need to enable lots of wonderful GHC extensions:

> {-# LANGUAGE MultiParamTypeClasses
>            , TemplateHaskell
>            , ScopedTypeVariables
>            , FlexibleInstances
>            , FlexibleContexts
>            , UndecidableInstances
>   #-}

You may be worried by `UndecidableInstances`.  Sadly, this is
necessary in order to typecheck the code generated by RepLib. Rest
assured, however, that the instances generated by RepLib *are*
decidable; it's just that GHC can't prove it.

Now for some imports: 

> import Generics.RepLib
> import Generics.RepLib.Bind.LocallyNameless

We import the RepLib library as well as the locally nameless
implementation of the binding library.  (RepLib also provides a nominal
version in `Generics.RepLib.Bind.Nominal`.  At the moment these are
simply two different implementations providing essentially the same
interface.  The locally nameless version is more mature, but you are
welcome to experiment with using the nominal version in its place.)

A few other imports we'll need for this particular example:

> import Control.Applicative
> import Control.Arrow ((+++))
> import Control.Monad
> import Control.Monad.Trans.Maybe
>
> import Text.Parsec hiding ((<|>))
> import qualified Text.Parsec.Token as P
> import Text.Parsec.Language (haskellDef)
>
> import qualified Text.PrettyPrint as PP
> import Text.PrettyPrint (Doc, (<+>))

**Representing terms**

We now declare a `Term` data type to represent lambda calculus terms.

> data Term = Var (Name Term)
>           | App Term Term
>           | Lam (Bind (Name Term) Term)
>   deriving Show

The `App` constructor is straightforward, but the other two
constructors are worth looking at in detail.

First, the `Var` constructor holds a `Name Term`.  `Name` is an
abstract type for representing names provided by RepLib.  `Name`s are
indexed by the sorts of things to which they can refer (or more
precisely, the sorts of things which can be substituted for them).
Here, a variable is simply a name for some `Term`, so we use the type
`Name Term`.

Lambdas are where names are *bound*, so we use the special `Bind` type
also provided by RepLib.  Somthing of type `Bind p b` represents a
pair consisting of a *pattern* `p` and a *body* `b`.  The pattern may
bind names which occur in `b`.  Here is where the power of generic
programming comes into play: we may use (almost) any types at all as
patterns and bodies, and RepLib will be able to handle it with very
little extra guidance from us.

In this particular case, a lambda simply binds a single name, so the
pattern is just a `Name Term`, and the body is just another `Term`.

Now we tell RepLib to automatically derive a bunch of
behind-the-scenes, boilerplate instances for `Term`:

> $(derive [''Term])

There are just a couple more things we need to do.  First, we make
`Term` an instance of `Alpha`, which provides most of the methods we
will need for working with the variables and binders within `Term`s.

> instance Alpha Term

What, no method definitions?  Nope!  In this case (and in most cases)
the default implementations, written in terms of those generic
instances we had RepLib derive for us, work just fine.  But in special
situations it's possible to override specific methods in the `Alpha`
class with our own implementations.

We only need to provide one more thing: a `Subst Term Term`
instance. In general, an instance for `Subst b a` means that we can
use the `subst` function to substitute things of type `b` for `Name`s
occurring in things of type `a`.  The only method we must implement
ourselves is `isvar`, which has the type

    isvar :: a -> Maybe (Name b, b -> a)

The documentation for `isvar` states "If the argument is a variable,
return its name and a function to generate a substituted term. Return
`Nothing` for non-variable arguments."  Even the most sophisticated
generic programming library can't read our minds: we have to tell it
which values of our data type are variables (*i.e.* things that can be
substituted for).  For `Term` this is not hard:

> instance Subst Term Term where
>   isvar (Var v) = Just (v, id)
>   isvar _       = Nothing

That's all!

**Trying things out**

Now that we've got the necessary preliminaries set up, what can we do
with this?  First, let's define some convenient helper functions:

> lam :: String -> Term -> Term
> lam x t = Lam $ bind (string2Name x) t
>
> var :: String -> Term
> var = Var . string2Name

Notice that `string2Name` allows us to create a `Name` from a
`String`, and `bind` allows us to construct bindings.

We can test things out at the `ghci` prompt like so:

    *Main> lam "x" (lam "y" (var "x"))
    Lam (<x> Lam (<y> Var 1@0))

The `1@0` is a *de Bruijn index*, which refers to the 0th variable of
the 1st (counting outwards from 0) enclosing binding site; that is, to
`x`.  Recall that the left-hand side of a `Bind` can be an arbitrary
data structure potentially containing multiple names (a *pattern*),
like a pair or a list; hence the need for the index after the `@`.  Of
course, in this particular example we only ever bind one name at once,
so the index after the `@` will always be zero.

We can check that substitution works as we expect. Substituting for
`x` in a term where `x` does not occur free has no effect:

    *Main> subst (string2Name "x") (var "z") (lam "x" (var "x"))
    Lam (<x> Var 0@0)
    
If `x` does occur free, the substitution takes place as expected:

    *Main> subst (string2Name "x") (var "z") (lam "y" (var "x"))
    Lam (<y> Var z)

Finally, substitution is capture-avoiding:

    *Main> subst (string2Name "x") (var "y") (lam "y" (var "x"))
    Lam (<y> Var y)

It may look at first glance like `y` has been incorrectly captured, but
the fact that it has a *name* means it is free: if it had been
captured we would see `Lam (<y> Var 0@0)`.

**Evaluation**

The first thing we want to do is write an evaluator for our lambda
calculus.  Of course there are many ways to do this; for the sake of
simplicity and illustration, we will write an evaluator based on a
small-step, call-by-value operational semantics.

> -- A convenient synonym for mzero
> done :: MonadPlus m => m a
> done = mzero
>
> step :: Term -> MaybeT FreshM Term
> step (Var _) = done
> step (Lam _) = done
> step (App (Lam b) t2) = do
>   (x,t1) <- unbind b
>   return $ subst x t2 t1
> step (App t1 t2) =
>       App <$> step t1 <*> pure t2
>   <|> App <$> pure t1 <*> step t2

We define a `step` function with the type `Term -> MaybeT FreshM
Term`.  `FreshM` is a monad provided by the binding library to handle
fresh name generation.  It's fairly simple but works just fine in many
situations.  (If you need to, you can create your own custom monad,
make it an instance of the `Fresh` class, and use it in place of
`FreshM`.)  In order to signal whether a reduction step has taken
place, we add failure capability with the `MaybeT` monad transformer.
We may freely intermix `FreshM` (which also comes in a transformer
variant, `FreshMT`) with all the standard monad transformers found in
the `transformers` package.

`step` tries to reduce the given term one step if possible.  Variables
and lambdas cannot be reduced at all, so in those cases we signal that
we are done. If the input term is an application of a lambda to
another term, we must do a beta-reduction.  We first use `unbind` to
destruct the binding inside the `Lam` constructor; it automatically
chooses a fresh name for the bound variable and gives us back a pair
of the variable and body.  We then call `subst` to perform the
appropriate substitution.

Otherwise, we must have an application of something other than a
lambda.  In this case we try reducing first the left-hand and then the
right-hand term.

Finally, we define an `eval` function as the transitive closure of
`step`, and run it with `runFreshM`:

> tc :: (Monad m, Functor m) => (a -> MaybeT m a) -> (a -> m a)
> tc f a = do
>   ma' <- runMaybeT (f a)
>   case ma' of
>     Just a' -> tc f a'
>     Nothing -> return a
>
> eval :: Term -> Term
> eval x = runFreshM (tc step x)

**Parsing**

We can use [Parsec](http://hackage.haskell.org/package/parsec) to
write a tiny parser for our lambda calculus:

> lexer = P.makeTokenParser haskellDef
> parens   = P.parens lexer
> brackets = P.brackets lexer
> ident    = P.identifier lexer
> 
> parseTerm = parseAtom `chainl1` (pure App)
> 
> parseAtom = parens parseTerm
>         <|> var <$> ident
>         <|> lam <$> (brackets ident) <*> parseTerm
> 
> runTerm :: String -> Either ParseError Term
> runTerm = (id +++ eval) . parse parseTerm ""

In fact, there's nothing particularly special about this parser with
respect to the binding library: we just get to reuse our `var` and
`lam` functions from before, with the result that strings like `"([x]
[y] x) x"` are parsed into terms with all the scoping properly
resolved.

To check that it works, let's compute 2 + 3:

    *Main> runTerm "([m][n][s][z] m s (n s z)) ([s] [z] s (s z)) ([s][z] s (s (s z))) s z"
    Right (App (Var s) (App (Var s) (App (Var s) (App (Var s) (App (Var s) (Var z))))))

2 + 3 is still 5, and all is right with the world.

**Pretty-printing and LFresh**

Now we want to write a pretty-printer for our lambda calculus (to use
in our fantastic type checking error messages, once we get around to
adding an amazing, sophisticated type system).  Here's a first attempt:

> class Pretty' p where
>   ppr' :: (Applicative m, Fresh m) => p -> m Doc
>
> instance Pretty' Term where
>   ppr' (Var x)     = return . PP.text . show $ x
>   ppr' (App t1 t2) = PP.parens <$> ((<+>) <$> ppr' t1 <*> ppr' t2)
>   ppr' (Lam b)     = do
>     (x, t) <- unbind b
>     ((PP.brackets . PP.text . show $ x) <+>) <$> ppr' t

However, there's a problem:

    *Main> runFreshM $ ppr' (lam "x" (lam "y" (lam "z" (var "y"))))
    [x] [y1] [z2] y1

Ugh, what are those numbers doing there?  The problem is that `unbind`
always generates a new globally fresh name no matter what other names
are or aren't in scope.  This is fine for evaluation, but for
pretty-printing terms that include bound names it's rather ugly.  For
nicer printing we'll need something a bit more sophisticated.

That something is the `LFresh` type class, which gives a slightly
different interface for generating *locally fresh* names (as opposed
to `Fresh` which generates globally fresh names).  A standard
`LFreshM` monad is provided (along with a corresponding transformer,
`LFreshMT`) which is an instance of `LFresh`.

    class Monad m => LFresh m where
      -- | Pick a new name that is fresh for the current (implicit) scope.
      lfresh  :: Rep a => Name a -> m (Name a)
      -- | Avoid the given names when freshening in the subcomputation.
      avoid   :: [AnyName] -> m a -> m a

Monads which are instances of `LFresh` maintain a set of names that
are to be avoided. `lfresh` generates a name which is guaranteed not
to be in the set, and `avoid` runs a subcomputation with some
additional names that should be avoided.  You probably won't need to
call these methods explicitly very often; more useful are some methods
built on top of these such as `lunbind`:

    lunbind :: (LFresh m, Alpha a, Alpha b) => Bind a b -> ((a, b) -> m c) -> m c

`lunbind` corresponds to `unbind` but works in an `LFresh` context.
It destructs a binding, avoiding only names curently in scope, and
runs a subcomputation while additionally avoiding the chosen name(s).

Let's rewrite our pretty-printer in terms of `LFresh`.  The only
change we need to make is to use a continuation-passing style for the
call to `lunbind` in place of the normal monadic sequencing used with
`unbind`.

> class Pretty p where
>   ppr :: (Applicative m, LFresh m) => p -> m Doc
>
> instance Pretty Term where
>   ppr (Var x)     = return . PP.text . show $ x
>   ppr (App t1 t2) = PP.parens <$> ((<+>) <$> ppr t1 <*> ppr t2)
>   ppr (Lam b)     =
>     lunbind b $ \(x,t) ->
>       ((PP.brackets . PP.text . show $ x) <+>) <$> ppr t

Let's try it:

    *Main> runLFreshM $ ppr (lam "x" (lam "y" (lam "z" (var "y"))))
    [x] [y] [z] y
  
    *Main> runLFreshM $ ppr (lam "x" (lam "y" (lam "y" (var "y"))))
    [x] [y] [y1] y1
  
Much better!
