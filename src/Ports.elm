port module Ports exposing (..)


type alias Flags =
    { src : String
    }


type alias ElmFile =
    { path : String
    , content : String
    }



-- OUT


port readFiles : List String -> Cmd msg


port successCb : String -> Cmd msg


port errorCb : String -> Cmd msg



-- IN


port typesIn : (List ElmFile -> msg) -> Sub msg
