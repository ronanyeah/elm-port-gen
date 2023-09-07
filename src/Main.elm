port module Main exposing (main)

import Elm.Parser
import Elm.Syntax.Declaration exposing (Declaration(..))
import Elm.Syntax.Node exposing (value)
import Elm.Syntax.TypeAnnotation exposing (TypeAnnotation(..))
import Json.Encode
import Platform exposing (worker)


main : Program Flags Model Msg
main =
    worker
        { init =
            \flags ->
                ( {}
                , Elm.Parser.parseToFile flags.src
                    |> Result.toMaybe
                    |> Maybe.map
                        (\file ->
                            buildFile
                                (file.declarations
                                    |> List.filterMap
                                        (\dec ->
                                            case value dec of
                                                PortDeclaration p ->
                                                    case value p.typeAnnotation of
                                                        FunctionTypeAnnotation a b ->
                                                            let
                                                                wrds =
                                                                    if isOut b then
                                                                        "PortOut<" ++ typeName a ++ ">"

                                                                    else
                                                                        "PortIn<" ++ getArgFromInPort a ++ ">"
                                                            in
                                                            value p.name
                                                                ++ ": "
                                                                ++ wrds
                                                                ++ ";"
                                                                |> Just

                                                        _ ->
                                                            Nothing

                                                _ ->
                                                    Nothing
                                        )
                                    |> String.join "\n  "
                                )
                                (file.declarations
                                    |> List.filterMap
                                        (\dec ->
                                            case value dec of
                                                AliasDeclaration p ->
                                                    case value p.typeAnnotation of
                                                        Record xs ->
                                                            ( value p.name
                                                            , "interface "
                                                                ++ value p.name
                                                                ++ " {\n  "
                                                                ++ (recordEntries xs
                                                                        |> String.join "\n  "
                                                                   )
                                                                ++ "\n}"
                                                            )
                                                                |> Just

                                                        _ ->
                                                            Nothing

                                                _ ->
                                                    Nothing
                                        )
                                    |> (\xs ->
                                            if List.isEmpty xs then
                                                ( "", "" )

                                            else
                                                ( "\n"
                                                    ++ String.join "\n\n"
                                                        (List.map
                                                            Tuple.second
                                                            xs
                                                        )
                                                    ++ "\n"
                                                , ", "
                                                    ++ String.join ", "
                                                        (List.map
                                                            Tuple.first
                                                            xs
                                                        )
                                                )
                                       )
                                )
                        )
                    |> Maybe.withDefault (Json.Encode.encode 0 Json.Encode.null)
                    |> export
                )
        , subscriptions = \_ -> Sub.none
        , update = \_ model -> ( model, Cmd.none )
        }


port export : String -> Cmd msg


type alias Flags =
    { src : String
    }


type alias Msg =
    ()


type alias Model =
    {}



--${types ? "\n" + types + "\n" : ""}


buildFile ports ( defs, exports ) =
    """/* This file was generated by github.com/ronanyeah/elm-port-gen */

interface ElmApp {
  ports: Ports;
}

interface Ports {
  $PORTS
}

interface PortOut<T> {
  subscribe: (_: (_: T) => void) => void;
}

interface PortIn<T> {
  send: (_: T) => void;
}
$DEFS
export { ElmApp$EXPORTS };"""
        |> String.replace "$PORTS" ports
        |> String.replace "$DEFS" defs
        |> String.replace "$EXPORTS" exports


typeName t =
    case value t of
        FunctionTypeAnnotation _ _ ->
            "zz"

        GenericType _ ->
            "zz"

        Typed typ args ->
            case Tuple.second (value typ) of
                "String" ->
                    "string"

                "Bool" ->
                    "boolean"

                "Value" ->
                    "any"

                "Int" ->
                    "number"

                "Float" ->
                    "number"

                "Maybe" ->
                    (args
                        |> List.head
                        |> Maybe.map typeName
                        |> Maybe.withDefault "opp"
                    )
                        ++ " | null"

                "List" ->
                    (args
                        |> List.head
                        |> Maybe.map typeName
                        |> Maybe.withDefault "opp"
                    )
                        ++ "[]"

                a ->
                    a

        Unit ->
            "null"

        Tupled xs ->
            xs
                |> List.map typeName
                |> String.join ", "
                |> (\str ->
                        "[" ++ str ++ "]"
                   )

        Record xs ->
            "{\n    " ++ (recordEntries xs |> String.join "\n    ") ++ "\n  }"

        GenericRecord _ _ ->
            "zz"


getArgFromInPort t =
    case value t of
        FunctionTypeAnnotation a _ ->
            typeName a

        _ ->
            "zz"


isOut t =
    case value t of
        Typed d _ ->
            value d
                |> Tuple.second
                |> (==) "Cmd"

        _ ->
            False


recordEntries xs =
    xs
        |> List.map value
        |> List.map
            (\( n, t ) ->
                value n ++ ": " ++ typeName t ++ ";"
            )
