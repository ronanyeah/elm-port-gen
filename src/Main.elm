port module Main exposing (main)

import Elm.Parser
import Elm.RawFile
import Json.Encode
import Platform exposing (worker)


main : Program Flags Model Msg
main =
    worker
        { init =
            \flags ->
                ( {}
                , Elm.Parser.parse flags.src
                    |> Result.toMaybe
                    |> Maybe.map Elm.RawFile.encode
                    |> Maybe.withDefault Json.Encode.null
                    |> Json.Encode.encode 2
                    |> log
                )
        , subscriptions = \_ -> Sub.none
        , update = \_ model -> ( model, Cmd.none )
        }


port log : String -> Cmd msg


type alias Flags =
    { src : String
    }


type alias Msg =
    ()


type alias Model =
    {}
