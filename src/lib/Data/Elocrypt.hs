{-|
Module:      Elocrypt.Passowrd
Description: Generate pronouncable, hard-to-guess passwords
Copyright:   (c) Sean Gillespie, 2015
License:     OtherLicense
Maintainer:  Sean Gillespie <sean@mistersg.net>
Stability:   Experimental

Generate easy-to-remember, hard-to-guess passwords
-}
module Data.Elocrypt where

import Data.Elocrypt.Trigraph

import Control.Monad
import Control.Monad.Random hiding (next)
import Data.Bool
import Data.Char
import Data.Maybe
import Prelude hiding (min, max)

-- * Data Types

-- |Options for generating passwords or passphrases. Do not use
-- this constructor directly. Instead use 'genOptions' to construct
-- an instance.
newtype GenOptions = GenOptions {
  genCapitals :: Bool
} deriving (Eq, Show)

-- |Default options for generating passwords or passphrases. This is
-- the preferred way to construct 'GenOptions'.
genOptions :: GenOptions
genOptions = GenOptions {genCapitals = False}

-- * Random password generators

-- |Generate a password using the generator g, returning the result and the
--  updated generator.
--
--  @
--  -- Generate a password of length 10 using the system generator
--  myGenPassword :: IO (String, StdGen)
--  myGenPassword = genPassword 10 genOptions \`liftM\` getStdGen
--  @
genPassword
  :: RandomGen g
  => Int        -- ^ password length
  -> GenOptions -- ^ options
  -> g          -- ^ random generator
  -> (String, g)
genPassword len = runRand . mkPassword len

-- |Plural version of genPassword.  Generates an infinite list of passwords
--  using the generator g, returning the result and the updated generator.
--
-- @
-- -- Generate 10 passwords of length 10 using the system generator
-- myGenPasswords :: IO ([String], StdGen)
-- myGenPasswords = (\(ls, g) -> (ls, g) `liftM` genPasswords 10 10 genOptions `liftM` getStdGen
-- @
genPasswords
  :: RandomGen g
  => Int        -- ^ password length
  -> Int        -- ^ number of passwords
  -> GenOptions -- ^ options
  -> g          -- ^ random generator
  -> ([String], g)
genPasswords len n = runRand . mkPasswords len n

-- |Generate a password using the generator g, returning the result.
--
--  @
--  -- Generate a password of length 10 using the system generator
--  myNewPassword :: IO String
--  myNewPassword = newPassword 10 genOptions \`liftM\` getStdGen
--  @
newPassword
  :: RandomGen g
  => Int        -- ^ password length
  -> GenOptions -- ^ options
  -> g          -- ^ random generator
  -> String
newPassword len = evalRand . mkPassword len

-- |Plural version of newPassword.  Generates an infinite list of passwords
--  using the generator g, returning the result
--
-- @
-- -- Generate 10 passwords of length 10 using the system generator
-- myNewPasswords :: IO [String]
-- myNewPasswords = genPasswords 10 10 genOptions `liftM` getStdGen
-- @
newPasswords
  :: RandomGen g
  => Int        -- ^ password length
  -> Int        -- ^ number of passwords
  -> GenOptions -- ^ options
  -> g          -- ^ random generator
  -> [String]
newPasswords len n = evalRand . mkPasswords len n

-- |Generate a password using the MonadRandom m. MonadRandom is exposed here
--  for extra control.
--
--  @
--  -- Generate a password of length 10 using the system generator
--  myPassword :: IO String
--  myPassword = evalRand (mkPassword 10 genOptions) \`liftM\` getStdGen
--  @
mkPassword
  :: MonadRandom m
  => Int        -- ^ password length
  -> GenOptions -- ^ options
  -> m String
mkPassword len opts = do
  f2 <- first2
  let f2' = reverse f2

  pass <- if len > 2 then lastN (len - 2) f2' else return (take len f2')
  let pass' = reverse pass

  if genCapitals opts then capitalizeR len pass' else return pass'

-- |Plural version of mkPassword.  Generate an infinite list of passwords using
--  the MonadRandom m.  MonadRandom is exposed here for extra control.
--
-- @
-- -- Generate an list of length 20 with passwords of length 10 using the system generator
-- myMkPasswords :: IO [String]
-- myMkPasswords = evalRand (mkPasswords 10 20 genOptions) \`liftM\` getStdGen
-- @
mkPasswords
  :: MonadRandom m
  => Int        -- ^ password length
  -> Int        -- ^ number of passwords
  -> GenOptions -- ^ options
  -> m [String]
mkPasswords len n = replicateM n . mkPassword len

-- * Random passphrase generators

-- |Generate a passphrase using the generator g, returning the result and the
--  updated generator.
--
--  @
--  -- Generate a passphrase of 10 words, each having a length between 6 and 12,
--  -- using the system generator
--  myGenPassphrase :: IO (String, StdGen)
--  myGenPassphrase = genPassword 10 6 10 genOptions \`liftM\` getStdGen
--  @
genPassphrase
  :: RandomGen g
  => Int        -- ^ number of words
  -> Int        -- ^ minimum word length
  -> Int        -- ^ maximum word length
  -> GenOptions -- ^ options
  -> g          -- ^ random generator
  -> ([String], g)
genPassphrase n min max = runRand . mkPassphrase n min max

-- |Generate a passphrase using the generator g, returning the result.
--
--  @
--  -- Generate a passphrase of 10 words, each having a length between 6 an 12,
--  -- using the system generator.
--  myNewPassphrase :: IO String
--  myNewPassphrase = newPassphrase 10 6 12 \`liftM\` getStdGen
--  @
newPassphrase
  :: RandomGen g
  => Int        -- ^ number of words
  -> Int        -- ^ minimum word length
  -> Int        -- ^ maximum word length
  -> GenOptions -- ^ options
  -> g          -- ^ random generator
  -> [String]
newPassphrase n min max = evalRand . mkPassphrase n min max

-- |Generate a finite number of words of random length (between @min@ and @max@ chars)
--  using the MonadRandom m. MonadRandom is exposed here for extra control.
--
--  @
--  -- Generate a passphrase of 10 words, each having a length between 6 and 12.
--  myPassphrase :: IO String
--  myPassphrase = evalRand (mkPassphrase 10 6 12) \`liftM\` getStdGen
--  @
mkPassphrase
  :: MonadRandom m
  => Int        -- ^ number of words
  -> Int        -- ^ minimum word length
  -> Int        -- ^ maximum word length
  -> GenOptions -- ^ options
  -> m [String]
mkPassphrase n min max opts =
  replicateM n $ getRandomR (min, max) >>= flip mkPassword opts

-- * Internal

-- |Generate two random characters. Uses 'Elocrypt.Trigraph.trigragh'
--  to generate a weighted list.
first2 :: MonadRandom m => m String
first2 = fromList (map toWeight frequencies)
  where toWeight (s, w) = (s, sum w)

-- |Generate the last n characters using previous two characters
--  and their 'Elocrypt.Trigraph.trigraph'
lastN :: MonadRandom m => Int -> String -> m String
lastN 0 ls = return ls
lastN len ls = next ls >>= lastN (len - 1) . (: ls)

-- |Generate a random character based on the previous two characters and
--  their 'Elocrypt.Trigraph.trigraph'
next
  :: MonadRandom m
  => String     -- ^ the prefix
  -> m Char
next = fromList . fromJust . findWeights . reverse . take 2

-- |Randomly capitalize at least 1 character. Additional characters capitalize
-- at a probability of 1/12
capitalizeR :: MonadRandom m => Int -> String -> m String
capitalizeR len s = mapM capitalize s >>= capitalize1 len
  where capitalize ch = fromList [(ch, 12), (toUpper ch, 1)]

-- |Randomly capitalize 1 character
capitalize1
  :: MonadRandom m
  => Int -- ^ length
  -> String -- ^ the string to capitalize
  -> m String
capitalize1 len s = capitalize1' <$> getRandomR (0, len - 1)
  where
    capitalize1' pos =
      let (prefix, ch : suffix) = splitAt (pos - 1) s
      in prefix ++ (toUpper ch : suffix)
