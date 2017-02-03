{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}

module Main where

import Control.Monad (forM_)
import Control.Distributed.Closure
import Control.Distributed.Spark.Closure
import Control.Distributed.Spark as RDD
import Data.Function (fix)
import Data.Int
import Language.Java
import Language.Java.Inline
import Criterion.Main as Criterion
import System.IO.Unsafe (unsafePerformIO)

jincr :: J ('Iface "org.apache.spark.api.java.function.Function")
jincr = unsafePerformIO $
      [java| new org.apache.spark.api.java.function.Function<Integer, Integer>() {
           public Integer call(Integer x) {
               return x + 1;
           }
       } |]

hincr :: J ('Iface "org.apache.spark.api.java.function.Function")
hincr = unsafeUngeneric . unsafePerformIO $ reflect (closure (static (\x -> (x :: Int32) + 1)))

mapJava :: RDD Int32 -> IO Int32
mapJava rdd = reify =<< [java| $rdd.map($jincr).count() |]

mapHaskell :: RDD Int32 -> IO Int32
mapHaskell rdd = reify =<< [java| $rdd.map($hincr).count() |]

main :: IO ()
main = do
    conf <- newSparkConf "RDD benchmarks"
    sc   <- getOrCreateSparkContext conf
    forM_ [0,200..10000 :: Int32] $ \x -> do
      putStrLn $ "Size " ++ show x
      rdd <- parallelize sc (replicate 1 x)
      Criterion.defaultMain $
        [ bgroup "map"
          [ bench "pure Java" $ nfIO $ mapJava rdd
          , bench "pure haskell" $ nfIO $ mapHaskell rdd
          ]
        ]
