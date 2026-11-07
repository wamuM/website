{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Routes.Snippets (snippetRoutes) where

import Web.Scotty
import Data.Aeson (FromJSON, ToJSON, Value, object, (.=))
import qualified Data.Aeson.Key as K
import Data.Yaml (decodeFileEither)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import System.Directory (doesFileExist)
import System.Random (randomRIO)
import Control.Monad.IO.Class (liftIO)
import Network.HTTP.Types.Status (status404, status500)
import Text.Ginger (parseGingerFile, easyRender)
import GHC.Generics (Generic)

notFoundPage :: ActionM a
notFoundPage = do
    status status404
    file "views/errors/404.html"
    finish

internalErrorPage :: TL.Text -> ActionM a
internalErrorPage err = do
    status status500
    text err
    finish

data Snippet = Snippet
    { name    :: Text
    , meta    :: Value 
    , content :: Text
    , visible :: Bool
    } deriving (Generic, Show)

instance FromJSON Snippet
instance ToJSON Snippet

type SnippetMap = Map Text Snippet

loadSnippets :: Text -> IO (Either String SnippetMap)
loadSnippets snippetType = do
    result <- decodeFileEither ("data/" ++ T.unpack snippetType ++ ".yaml")
    case result of
        Left err -> return (Left $ show err)
        Right snippetMap -> return (Right snippetMap)

loadFileMaybe :: FilePath -> IO (Maybe String)
loadFileMaybe fp = do
    exists <- doesFileExist fp
    if exists
        then Just <$> readFile fp
        else return Nothing

getSnippet :: Text -> Text -> ActionM Snippet 
getSnippet snippetType snippetId = do
    eSnippets <- liftIO $ loadSnippets snippetType
    case eSnippets of
        Left err -> internalErrorPage (TL.pack $ show err)
        Right snippetMap -> case Map.lookup snippetId snippetMap of
            Just snippet | visible snippet -> return snippet
            _ -> notFoundPage

snippetRoutes :: Text -> Text -> ScottyM ()
snippetRoutes snippetType rawUrl = do
    let cleanUrl = T.dropAround (== '/') rawUrl
        basePath = "/" ++ T.unpack cleanUrl
        baseUrl  = "/" <> cleanUrl

    get (capture basePath) $ 
        serveRandomSnippet snippetType baseUrl

    get (capture $ basePath ++ "/random") $ 
        serveRandomSnippet snippetType baseUrl

    get (capture $ basePath ++ "/:id") $ do
        snippetId <- pathParam "id"
        snippet   <- getSnippet snippetType snippetId 
        serveSnippet snippetType snippet (baseUrl <> "/" <> snippetId)
  where
    serveSnippet :: Text -> Snippet -> Text -> ActionM ()
    serveSnippet sType snippet fullUrl = do
        let templatePath = "views/templates/" ++ T.unpack sType ++ ".html"
        templateExists <- liftIO $ doesFileExist templatePath
        if not templateExists 
            then internalErrorPage "Template missing" 
            else do
                parsedTemplate <- liftIO $ parseGingerFile loadFileMaybe templatePath
                case parsedTemplate of
                    Left err -> internalErrorPage ("Template parser error:\n" <> TL.pack (show err))
                    Right template -> do
                        -- K.fromText converts Text to Data.Aeson.Key
                        let context = object [K.fromText sType .= snippet, "url" .= fullUrl]
                        let renderedHtml = easyRender context template
                        html $ TL.fromStrict renderedHtml

    serveRandomSnippet :: Text -> Text -> ActionM ()
    serveRandomSnippet sType snippetUrl = do
        eSnippets <- liftIO $ loadSnippets sType
        case eSnippets of
            Left err -> internalErrorPage ("Error reading data:\n" <> TL.pack (show err))
            Right snippetMap -> do
                let visibleSnippets = Map.filter visible snippetMap
                let snippetIds = Map.keys visibleSnippets
                if null snippetIds 
                    then notFoundPage
                    else do
                        idx <- liftIO $ randomRIO (0, length snippetIds - 1)
                        let chosenId = snippetIds !! idx
                        redirect $ TL.fromStrict $ "/" <> T.dropAround (== '/') snippetUrl <> "/" <> chosenId
