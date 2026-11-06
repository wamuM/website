{-# LANGUAGE DeriveGeneric #-}

module Routes.Goodies (goodiesRoutes) where

import Web.Scotty
import Text.Ginger (parseGingerFile, easyRender)
import Data.Yaml (decodeFileEither)
import Data.Aeson (FromJSON, ToJSON, toJSON, Value(Object), object, (.=))
import qualified Data.Aeson.KeyMap as KeyMap
import GHC.Generics (Generic)
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import System.Random (randomRIO)
import System.FilePath ((</>), splitDirectories)
import System.Directory (doesFileExist)
import Network.HTTP.Types.Status (status404, status500)
import Control.Monad.IO.Class (liftIO)

data Goodie = Goodie
    { name        :: Text
    , path        :: FilePath
    , description :: Text
    , visible     :: Bool
    } deriving (Generic, Show)

instance FromJSON Goodie
instance ToJSON Goodie

type GoodiesMap = Map Text Goodie

goodieWithId :: Text -> Goodie -> Value
goodieWithId rId goodie = case toJSON goodie of
    Object km -> Object (KeyMap.insert "id" (toJSON rId) km)
    other -> other

loadGoodies :: IO (Either String GoodiesMap)
loadGoodies = do
    result <- decodeFileEither "goodies/data.yaml"
    case result of
        Left err -> return (Left $ show err)
        Right goodiesMap -> return (Right goodiesMap)

notFoundPage :: ActionM ()
notFoundPage = do
    status status404
    file "views/errors/404.html"

serveGoodieFile :: Text -> FilePath -> ActionM()
serveGoodieFile rId requestSubPath = do 
    eGoodies <- liftIO loadGoodies
    case eGoodies of
        Right goodiesMap | Just goodie <- Map.lookup rId goodiesMap, visible goodie -> do
            let relPath = if null requestSubPath then "index.html" else requestSubPath
            let isSafePath = ".." `notElem` splitDirectories relPath
            let targetFile = "goodies" </> path goodie </> relPath
            exists <- liftIO $ doesFileExist targetFile
            if isSafePath && exists
                then file targetFile
                else notFoundPage
        _ -> notFoundPage

loadFileMaybe :: FilePath -> IO (Maybe String)
loadFileMaybe fn = do
    exists <- doesFileExist fn
    if exists
        then Just <$> readFile fn
        else return Nothing

goodiesRoutes :: ScottyM ()
goodiesRoutes = do
    get "/goodies/" serveList
    get "/goodies"  serveList

    get "/goodies/random" $ do
        eGoodies <- liftIO loadGoodies
        case eGoodies of
            Left err -> status status500 >> (text $ "Error reading goodies/data.yaml:\n" <> TL.pack (show err))
            Right goodiesMap -> do
                let visibleGoodies = Map.filter visible goodiesMap
                let goodieKeys = Map.keys visibleGoodies
                if null goodieKeys
                    then notFoundPage 
                    else do
                        idx <- liftIO $ randomRIO (0, length goodieKeys - 1)
                        let chosenId = goodieKeys !! idx
                        redirect $ TL.fromStrict $ "/goodies/" <> chosenId

    get "/goodies/:goodieid" $ do
        rId <- pathParam "goodieid"
        serveGoodieFile rId ""

    get (regex "^/goodies/([^/]+)/(.*)$") $ do
        rId <- pathParam "1"
        subPath <- pathParam "2"
        serveGoodieFile rId subPath

  where
    serveList = do
        templateExists <- liftIO $ doesFileExist "views/templates/goodies.html"
        if not templateExists
            then status status500 >> text "Template views/templates/goodies.html missing"
            else do
                parsed <- liftIO $ parseGingerFile loadFileMaybe "views/templates/goodies.html"
                case parsed of
                    Left err -> status status500 >> (text $ "Template parser error:\n" <> TL.pack (show err))
                    Right template -> do
                        eGoodies <- liftIO loadGoodies
                        case eGoodies of
                            Left err -> status status500 >> (text $ "Error reading goodies/data.yaml:\n" <> TL.pack (show err))
                            Right goodiesMap -> do
                                let goodieObjects = [ goodieWithId rId goodie | (rId, goodie) <- Map.toList goodiesMap, visible goodie]
                                let context = object ["goodies" .= goodieObjects]
                                let renderedHtml = easyRender context template
                                html $ TL.fromStrict renderedHtml
