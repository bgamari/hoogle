
module Hoogle.DataBase.Items where

import Control.Monad.State
import Data.Maybe
import General.Index
import Hoogle.TextBase.All
import qualified Data.Map as Map
import Hoogle.Item.All


data Items = Items
    {packages :: Index Package
    ,modules :: Index Module
    ,entrys :: Index Entry
    }


-- temporary state structure
data S = S {pkg :: Package
           ,modId :: Int
           ,mods :: [Module]
           ,modCur :: Maybe (Lookup Module)
           ,entId :: Int
           ,ents :: [(TextItem, Maybe Entry)]
           }

createItems :: [TextItem] -> (Items, [(TextItem, Maybe Entry)])
createItems xs = res
    where
        s0 = S (Package 0 "" "" "" "") 0 [] Nothing 0 []
        res = unS $ execState (mapM f xs) s0

        unS s = (Items (newIndex [pkg s])
                       (newIndex $ reverse $ mods s)
                       (newIndex $ reverse $ mapMaybe snd $ ents s)
                ,ents s)

        f :: TextItem -> State S ()
        f i@ItemInstance{} = addTextItem i

        f i@(ItemAttribute "keyword" name) = addEntry i False
                [Keyword "keyword",Text " ",Focus name]

        f i@(ItemAttribute name val) = do
            addTextItem i
            when (name == "package") $ modify $ \s -> s{pkg = (pkg s){packageName = val}}
            when (name == "version") $ modify $ \s -> s{pkg = (pkg s){packageVersion = val}}

        f i@(ItemModule xs) = do
            s <- get
            let modI = modId s
                m = Module modI xs (newLookup 0 $ packages $ fst res)
            put s{modId = modI + 1, mods = m : mods s
                 ,modCur = Just $ newLookup modI $ modules $ fst res}
            addEntry i False
                [Keyword "module", Text $ ' ' : concatMap (++ ".") (init xs), Focus (last xs)]

        f i = addEntry i True (render i)


        render (ItemClass i) = [Keyword "class", Text " ", Text (show i)]
        render (ItemFunc name typ) = [Focus name, Text " :: ", Text (show typ)]
        render (ItemAlias a b) = [Keyword "type", Text (" " ++ show a ++ " = " ++ show b)]
        render (ItemData d t) = [Keyword (show d), Text (show t)]

        addTextItem i = modify $ \s -> s{ents = (i,Nothing) : ents s}

        addEntry i modu txt = do
            s <- get
            let entI = entId s
                e = Entry entI (if modu then modCur s else Nothing) txt
            put $ s{entId = entI + 1, ents = (i, Just e) : ents s}