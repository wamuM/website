module Main (main) where

import System.Environment (lookupEnv)
import Data.Maybe (fromMaybe)
import Text.Read (readMaybe)
import Web.Scotty
import Network.Wai.Middleware.Static (staticPolicy, noDots, hasPrefix, (>->))

import Routes.Rooms (roomsRoutes)
import Routes.Snippets (snippetRoutes)

main :: IO ()
main = do
  portEnv <- lookupEnv "PORT"
  let port = fromMaybe 8080 (portEnv >>= readMaybe)

  putStrLn $ "Starting server on port " ++ show port
  scotty port $ do
    middleware $ staticPolicy (noDots >-> hasPrefix "static") 

    get "/" $ redirect "/landing"
    get "/landing" $ file "views/landing.html"

    get "/contact" $ file "views/contact.html"
    get "/pgp" $ file "views/pgp.html"
    get "/portfolio" $ file "views/portfolio.html"

    get "/ai-usage" $ file "views/ai-usage.html"
    get "/license" $ file "views/license.html"

    get "/webring" $ file "views/webring.html"
    get "/adyton" $ file "views/adyton.html"

    get "/mansion" $ file "views/mansion.html"

    roomsRoutes
    snippetRoutes "quotes" "api/quotes"
    snippetRoutes "goodies" "goodies"

    notFound $ file "views/errors/404.html"

    

