port module Main exposing (main)

import Elm.Parser
import Elm.Syntax.Declaration exposing (Declaration(..))
import Elm.Syntax.File
import Elm.Syntax.Node as Node
import Elm.Syntax.TypeAnnotation exposing (TypeAnnotation(..))
import Parser
import Platform exposing (worker)
import Result.Extra


main : Program Flags {} ()
main =
    worker
        { init =
            \flags ->
                ( {}
                , Elm.Parser.parseToFile flags.src
                    |> Result.mapError Parser.deadEndsToString
                    |> Result.andThen handleFile
                    |> Result.Extra.unpack errorCb successCb
                )
        , subscriptions = \_ -> Sub.none
        , update = \_ model -> ( model, Cmd.none )
        }


port successCb : String -> Cmd msg


port errorCb : String -> Cmd msg


type alias Flags =
    { src : String
    }



---


handleFile : Elm.Syntax.File.File -> Result String String
handleFile file =
    Result.map2 buildFile
        (extractPorts file)
        (extractDefinitions file)


extractDefinitions : Elm.Syntax.File.File -> Result String (List ( String, String ))
extractDefinitions file =
    file.declarations
        |> List.filterMap
            (\dec ->
                case Node.value dec of
                    AliasDeclaration p ->
                        case Node.value p.typeAnnotation of
                            Record xs ->
                                if Node.value p.name == "PortResult" then
                                    Nothing

                                else
                                    recordEntries xs
                                        |> Result.map
                                            (\val ->
                                                ( Node.value p.name
                                                , "interface "
                                                    ++ Node.value p.name
                                                    ++ " {\n  "
                                                    ++ (val
                                                            |> String.join "\n  "
                                                       )
                                                    ++ "\n}"
                                                )
                                            )
                                        |> Just

                            _ ->
                                Nothing

                    _ ->
                        Nothing
            )
        |> Result.Extra.combine


extractPorts : Elm.Syntax.File.File -> Result String (List String)
extractPorts file =
    file.declarations
        |> List.filterMap
            (\dec ->
                case Node.value dec of
                    PortDeclaration p ->
                        case Node.value p.typeAnnotation of
                            FunctionTypeAnnotation a b ->
                                let
                                    wrds =
                                        if isOut b then
                                            typeName a
                                                |> Result.map
                                                    (\val ->
                                                        "PortOut<" ++ val ++ ">"
                                                    )

                                        else
                                            getArgFromInPort a
                                                |> Result.map
                                                    (\val ->
                                                        "PortIn<" ++ val ++ ">"
                                                    )
                                in
                                wrds
                                    |> Result.map
                                        (\w ->
                                            Node.value p.name
                                                ++ ": "
                                                ++ w
                                                ++ ";"
                                        )
                                    |> Just

                            _ ->
                                Nothing

                    _ ->
                        Nothing
            )
        |> Result.Extra.combine


buildFile : List String -> List ( String, String ) -> String
buildFile portData defsData =
    let
        ports =
            portData
                |> String.join "\n  "

        ( defs, exports ) =
            if List.isEmpty defsData then
                ( "", "" )

            else
                ( "\n"
                    ++ String.join "\n\n"
                        (List.map
                            Tuple.second
                            defsData
                        )
                    ++ "\n"
                , ", "
                    ++ String.join ", "
                        (List.map
                            Tuple.first
                            defsData
                        )
                )
    in
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

type PortResult<E, T> =
    | { err: E; data: null }
    | { err: null; data: T };
$DEFS
function portOk<E, T>(data: T): PortResult<E, T> {
  return { data, err: null };
}

function portErr<E, T>(err: E): PortResult<E, T> {
  return { data: null, err };
}

export { ElmApp, PortResult, portOk, portErr$EXPORTS };"""
        |> String.replace "$PORTS" ports
        |> String.replace "$DEFS" defs
        |> String.replace "$EXPORTS" exports


typeName : Node.Node TypeAnnotation -> Result String String
typeName t =
    case Node.value t of
        FunctionTypeAnnotation _ _ ->
            "TodoFunctionTypeAnnotation_"
                |> Err

        GenericType val ->
            "TodoGenericType_"
                ++ val
                |> Err

        Typed typ args ->
            case Tuple.second (Node.value typ) of
                "String" ->
                    Ok "string"

                "Bool" ->
                    Ok "boolean"

                "Value" ->
                    Ok "any"

                "Int" ->
                    Ok "number"

                "Float" ->
                    Ok "number"

                "Maybe" ->
                    args
                        |> List.head
                        |> Result.fromMaybe "no maybe arg"
                        |> Result.andThen typeName
                        |> Result.map
                            (\val ->
                                val ++ " | null"
                            )

                "List" ->
                    args
                        |> List.head
                        |> Result.fromMaybe "no list arg"
                        |> Result.andThen typeName
                        |> Result.map
                            (\val ->
                                val ++ "[]"
                            )

                "Array" ->
                    args
                        |> List.head
                        |> Result.fromMaybe "no array arg"
                        |> Result.andThen typeName
                        |> Result.map
                            (\val ->
                                val ++ "[]"
                            )

                "PortResult" ->
                    args
                        |> List.map typeName
                        |> Result.Extra.combine
                        |> Result.map
                            (\val ->
                                "PortResult<"
                                    ++ String.join ", " val
                                    ++ ">"
                            )

                a ->
                    Ok a

        Unit ->
            Ok "null"

        Tupled xs ->
            xs
                |> List.map typeName
                |> Result.Extra.combine
                |> Result.map
                    (\val ->
                        "[" ++ String.join ", " val ++ "]"
                    )

        Record xs ->
            recordEntries xs
                |> Result.map
                    (\val ->
                        "{\n    " ++ (val |> String.join "\n    ") ++ "\n  }"
                    )

        GenericRecord _ _ ->
            Err "TodoGenericRecord_"


getArgFromInPort : Node.Node TypeAnnotation -> Result String String
getArgFromInPort t =
    case Node.value t of
        FunctionTypeAnnotation a _ ->
            typeName a

        _ ->
            Err "TodoArgIn_"


isOut : Node.Node TypeAnnotation -> Bool
isOut t =
    case Node.value t of
        Typed d _ ->
            Node.value d
                |> Tuple.second
                |> (==) "Cmd"

        _ ->
            False


recordEntries : List (Node.Node ( Node.Node String, Node.Node TypeAnnotation )) -> Result String (List String)
recordEntries xs =
    xs
        |> List.map Node.value
        |> List.map
            (\( n, t ) ->
                typeName t
                    |> Result.map
                        (\val ->
                            Node.value n ++ ": " ++ val ++ ";"
                        )
            )
        |> Result.Extra.combine
