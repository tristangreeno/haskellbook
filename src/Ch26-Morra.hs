
module Morra where

import Control.Monad.IO.Class
import Control.Monad.Trans.Reader
import Data.Bifunctor
import Data.IORef
import System.Exit
import System.IO
import System.Random

data Command a = Valid a | Invalid | Quit

type PersonGuess = Int
type PersonScore = Int
type Name = String
type Names = (Name, Name)
type Score = (PersonScore, PersonScore)
type Turn = (PersonGuess, PersonGuess)
data Mode = AI2P | P2P
data GameState = GameState { score :: Score
                 , turns :: [Turn]
                 }
data Game = Game {
  gameState :: IORef GameState
  , mode :: Mode
  }

updateScore :: Turn -> Score -> Score
updateScore (cg, pg) =
  if even $ cg + pg
  then first (+1)
  else second (+1)

gameWinner :: Names -> Score -> String
gameWinner (p1, p2) s =
  case uncurry compare s of
    GT -> "Way to go, " ++ p1 ++ "!"
    EQ -> "It is a draw!"
    LT -> "Way to go, " ++ p2 ++ "!"

turnWinner :: Names -> Turn -> String
turnWinner ns ts =
  if even $ uncurry (+) ts
  then "- " ++ fst ns ++ " wins"
  else "- " ++ snd ns ++ " wins"

parseInput :: Char -> Command PersonGuess
parseInput ch
  | ch `elem` "Qq" = Quit
  | ch `elem` "12" = Valid $ read [ch]
  | otherwise = Invalid

parseMode :: Char -> Either String Mode
parseMode ch
  | ch `elem` "Pp" = Right P2P
  | ch `elem` "Cc" = Right AI2P
  | otherwise = Left $ "Key pressed: " ++ [ch]

invalid :: IO ()
invalid = putStrLn "Type 1, 2 or Q for quit"

quit :: Names -> Score -> IO ()
quit (p1, p2) (s1, s2) = do
  putStrLn $ concat [ "Final score -- " ++ p1 ++ ": "
                    , show $ s1
                    , " " ++ p2 ++ ": "
                    , show $ s2 ]
  putStrLn $ gameWinner (p1, p2) (s1, s2)
  putStrLn "Quitting..."
  exitSuccess

gameRoutine :: Game -> IO ()
gameRoutine (Game ref m) = do
  st <- readIORef ref
  let score' = score st
      turns' = turns st
  case m of
    AI2P -> do
      let p1 = "C" :: Name
          p2 = "P" :: Name
          quit' = quit (p1, p2) score'
      putStr $ p2 ++ ": " -- prompt person to play
      input <- getChar -- person guess
      _ <- getChar -- consuming newline, so it doesn't come back later
      aiGuess <- randomRIO (1, 2) :: IO PersonGuess -- AI guess
      putStrLn (p1 ++ ": " ++ show aiGuess) -- reveal AI guess
      case parseInput input of
        Invalid -> invalid
        Quit -> quit'  
        Valid pGuess -> do
          let turn = (aiGuess, pGuess) :: Turn
          writeIORef ref $ GameState (updateScore turn score') (turn:turns')
          putStrLn $ turnWinner (p1, p2) turn
    P2P -> do
      let players = ("P1", "P2") :: (Name, Name)
          quit' = quit players score'
      g1 <- p2p $ fst players
      g2 <- p2p $ snd players
      case g1 of
        Quit -> quit'
        Invalid -> invalid
        Valid g1' ->
          case g2 of
            Quit -> quit'
            Invalid -> invalid
            Valid g2' -> do
              let turn = (g1', g2') :: Turn
              writeIORef ref $ GameState (updateScore turn score') (turn:turns')
              putStrLn $ turnWinner players turn
              gameRoutine (Game ref P2P)

p2p :: Name -> IO (Command PersonGuess)
p2p p = do
  putStr $ p ++ ": "
  input <- getChar
  _ <- getChar
  return $ parseInput input

app :: ReaderT Game IO ()
app = do
  config <- ask
  liftIO $ gameRoutine config
  app

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStrLn "*********Set game mode: *********"
  putStrLn "* P for Person to Person        *"
  putStrLn "* C for Person vs AI (Computer) *"
  putStrLn "******any other key to quit******"
  putStr "Selection: "
  m <- getChar
  _ <- getChar
  case parseMode m of
    Left e -> putStrLn e >> exitSuccess
    Right m' -> do
      newGame <- newIORef $ GameState (0,0) []
      let config = Game newGame m'
          run r = runReaderT r config
      run app