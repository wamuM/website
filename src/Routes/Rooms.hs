{-# LANGUAGE DeriveGeneric #-}

module Routes.Rooms (roomsRoutes) where

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

data Room = Room
    { name        :: Text
    , path        :: FilePath
    , description :: Text
    , visible     :: Bool
    } deriving (Generic, Show)

instance FromJSON Room
instance ToJSON Room

type RoomsMap = Map Text Room

roomWithId :: Text -> Room -> Value
roomWithId rId room = case toJSON room of
    Object km -> Object (KeyMap.insert "id" (toJSON rId) km)
    other -> other

loadRooms :: IO (Either String RoomsMap)
loadRooms = do
    result <- decodeFileEither "rooms/data.yaml"
    case result of
        Left err -> return (Left $ show err)
        Right roomsMap -> return (Right roomsMap)

notFoundPage :: ActionM ()
notFoundPage = do
    status status404
    file "views/errors/404.html"

serveRoomFile :: Text -> FilePath -> ActionM()
serveRoomFile rId requestSubPath = do 
    eRooms <- liftIO loadRooms
    case eRooms of
        Right roomsMap | Just room <- Map.lookup rId roomsMap, visible room -> do
            let relPath = if null requestSubPath then "index.html" else requestSubPath
            let isSafePath = ".." `notElem` splitDirectories relPath
            let targetFile = "rooms" </> path room </> relPath
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

roomsRoutes :: ScottyM ()
roomsRoutes = do
    get "/rooms/" serveList
    get "/rooms"  serveList

    get "/rooms/random" $ do
        eRooms <- liftIO loadRooms
        case eRooms of
            Left err -> status status500 >> (text $ "Error reading rooms/data.yaml:\n" <> TL.pack (show err))
            Right roomsMap -> do
                let visibleRooms = Map.filter visible roomsMap
                let roomKeys = Map.keys visibleRooms
                if null roomKeys
                    then notFoundPage 
                    else do
                        idx <- liftIO $ randomRIO (0, length roomKeys - 1)
                        let chosenId = roomKeys !! idx
                        redirect $ TL.fromStrict $ "/rooms/" <> chosenId

    get "/rooms/:roomid" $ do
        rId <- pathParam "roomid"
        serveRoomFile rId ""

    get (regex "^/rooms/([^/]+)/(.*)$") $ do
        rId <- pathParam "1"
        subPath <- pathParam "2"
        serveRoomFile rId subPath

  where
    serveList = do
        templateExists <- liftIO $ doesFileExist "views/templates/rooms.html"
        if not templateExists
            then status status500 >> text "Template views/templates/rooms.html missing"
            else do
                parsed <- liftIO $ parseGingerFile loadFileMaybe "views/templates/rooms.html"
                case parsed of
                    Left err -> status status500 >> (text $ "Template parser error:\n" <> TL.pack (show err))
                    Right template -> do
                        eRooms <- liftIO loadRooms
                        case eRooms of
                            Left err -> status status500 >> (text $ "Error reading rooms/data.yaml:\n" <> TL.pack (show err))
                            Right roomsMap -> do
                                let roomObjects = [ roomWithId rId room | (rId, room) <- Map.toList roomsMap, visible room]
                                let context = object ["rooms" .= roomObjects]
                                let renderedHtml = easyRender context template
                                html $ TL.fromStrict renderedHtml
