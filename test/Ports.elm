port module Ports exposing (..)


type alias Data =
    { name : String
    , amount : Int
    }



-- OUT


port stop : () -> Cmd msg


port log : String -> Cmd msg


port sendData : Data -> Cmd msg



-- IN


port callback : (() -> msg) -> Sub msg


port read : (String -> msg) -> Sub msg


port receiveData : (Data -> msg) -> Sub msg
