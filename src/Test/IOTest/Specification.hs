{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DataKinds #-}
module Test.IOTest.Specification (
  Specification(..),
  Action (..),
  optional,
) where

import Prelude hiding (foldr)

import Test.IOTest.Utils
import Test.IOTest.Environment
import Test.IOTest.Term
import Test.IOTest.Pattern
import Test.IOTest.ValueSet

import Data.List (nub)
import Data.MonoTraversable
import Data.MonoTraversable.Unprefixed (foldr)

import Text.PrettyPrint.Annotated.HughesPJClass hiding ((<>))

newtype Specification t = Spec [Action t]
  deriving (Semigroup, Monoid, MonoFoldable) via [Action t]

-- for MonoFoldable
type instance Element (Specification t) = Action t

data Action t where
  ReadInput :: Varname -> ValueSet -> Action t
  WriteOutput :: StringEmbedding a => Bool -> [TermPattern] -> [t a] -> Action t
  Branch :: t Bool -> Specification t -> Specification t -> Action t
  TillE :: Specification t -> Action t
  E :: Action t

instance TermVars t => Show (Specification t) where
  show = render . pPrint

instance TermVars t => Show (Action t) where
  show = render . pPrint

instance TermVars t => Pretty (Specification t) where
  pPrint (Spec as) = vcat $ pPrint <$> as

instance TermVars t => Pretty (Action t) where
  pPrint (ReadInput x _) = text "ReadInput" <+> text (show x) <+> text "_"
  pPrint (WriteOutput b ps ts) = hsep [text "WriteOutput", text (show b), text (show ps), text "_{", text (show (termVars <$> ts)), text "}"]
  pPrint (Branch c s1 s2) = hang (text "Branch _{" <+> text (show $ termVars c) <+> text "}") 2 (parens (pPrint s1) $+$ parens (pPrint s2))
  pPrint (TillE s) = hang (text "TillE") 2 (parens (pPrint s))
  pPrint E = text "E"

-- move into Combinators ?
optional :: Specification t -> Specification t
optional (Spec []) = Spec []
optional (Spec (WriteOutput _ ps ts : xs)) = Spec [WriteOutput True ps ts] <> optional (Spec xs)
optional _ = error "only writes can be optional"

instance TermVars t => HasVariables (Specification t) where
  vars = nub . foldr phi [] where
    phi (ReadInput v _) vs = v : vs
    phi (WriteOutput _ _ ts) vs = concatMap termVars ts ++ vs
    phi (TillE s) vs = vars s ++ vs
    phi (Branch c s1 s2) vs = termVars c ++ vars s1 ++ vars s2 ++ vs
    phi E vs = vs
