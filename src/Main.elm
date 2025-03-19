module Main exposing (main)

import Dict exposing (Dict)
import Elm.Parser
import Elm.Syntax.Declaration exposing (Declaration(..))
import Elm.Syntax.File
import Elm.Syntax.Node as Node
import Elm.Syntax.TypeAnnotation exposing (TypeAnnotation(..))
import Maybe.Extra
import Parser
import Platform
import Ports
import Result.Extra
import Set


main : Program Ports.Flags Model Msg
main =
    Platform.worker
        { init =
            \flags ->
                Elm.Parser.parseToFile flags.src
                    |> Result.Extra.unpack
                        (\err ->
                            ( { portsFile = Nothing
                              , externalImports = []
                              }
                            , Ports.errorCb
                                ("port file failed:\n"
                                    ++ Parser.deadEndsToString err
                                )
                            )
                        )
                        (\file ->
                            let
                                externals =
                                    extractImports file

                                modulesToImport =
                                    externals
                                        |> List.map .modulePath
                                        |> Set.fromList
                                        |> Set.toList
                            in
                            ( { portsFile = Just file
                              , externalImports = externals
                              }
                            , Ports.readFiles modulesToImport
                            )
                        )
        , subscriptions =
            \_ ->
                Ports.typesIn FilesCb
        , update =
            \msg model ->
                case msg of
                    FilesCb fileRes ->
                        model.portsFile
                            |> Maybe.Extra.unwrap
                                ( model, Ports.errorCb "file not persisted" )
                                (\file ->
                                    matchImports file fileRes model.externalImports
                                        |> Result.Extra.unpack
                                            (\err ->
                                                ( model
                                                , Ports.errorCb err
                                                )
                                            )
                                            (\markup ->
                                                ( model
                                                , Ports.successCb markup
                                                )
                                            )
                                )
        }


type Msg
    = FilesCb (List Ports.ElmFile)


type alias Model =
    { portsFile : Maybe Elm.Syntax.File.File
    , externalImports : List ExternalImport
    }


type alias ExternalImport =
    { modulePath : String
    , recordName : String
    }


type alias RecordDef =
    { name : String
    , body : String
    }



---


matchImports : Elm.Syntax.File.File -> List Ports.ElmFile -> List ExternalImport -> Result String String
matchImports portsFile otherImports importsToMatch =
    let
        importedFilesRes =
            otherImports
                |> List.map
                    (\data ->
                        data.content
                            |> Elm.Parser.parseToFile
                            |> Result.mapError Parser.deadEndsToString
                            |> Result.andThen extractRecordDefinitions
                            |> Result.map
                                (\defs ->
                                    ( data.path
                                    , defs
                                    )
                                )
                    )
                |> Result.Extra.combine
                |> Result.map Dict.fromList

        importDefs =
            importedFilesRes
                |> Result.andThen
                    (findExternalImports importsToMatch)
    in
    Result.map3
        (\externals ports origDefs ->
            buildFile ports
                (externals ++ origDefs)
        )
        importDefs
        (extractPorts portsFile)
        (extractDefinitions portsFile)


findExternalImports : List ExternalImport -> Dict String (Dict String String) -> Result String (List RecordDef)
findExternalImports externalImports files =
    externalImports
        |> List.map
            (\data ->
                files
                    |> Dict.get data.modulePath
                    |> Result.fromMaybe
                        ("module not found: " ++ data.modulePath)
                    |> Result.andThen
                        (\defs ->
                            Dict.get data.recordName defs
                                |> Result.fromMaybe
                                    ("record not found: "
                                        ++ data.recordName
                                    )
                        )
                    |> Result.map
                        (\body ->
                            { name = data.recordName
                            , body = body
                            }
                        )
            )
        |> Result.Extra.combine


extractRecordDefinitions : Elm.Syntax.File.File -> Result String (Dict String String)
extractRecordDefinitions file =
    file.declarations
        |> List.filterMap
            (\dec ->
                case Node.value dec of
                    AliasDeclaration p ->
                        case Node.value p.typeAnnotation of
                            Record xs ->
                                let
                                    name =
                                        Node.value p.name
                                in
                                recordEntries xs
                                    |> Result.map
                                        (\val ->
                                            ( name
                                            , buildInterface name val
                                            )
                                        )
                                    |> Just

                            _ ->
                                Nothing

                    _ ->
                        Nothing
            )
        |> Result.Extra.combine
        |> Result.map Dict.fromList


extractImports : Elm.Syntax.File.File -> List ExternalImport
extractImports file =
    file.declarations
        |> List.filterMap
            (\dec ->
                case Node.value dec of
                    AliasDeclaration p ->
                        case Node.value p.typeAnnotation of
                            Typed a _ ->
                                case Node.value a of
                                    ( modulePath, definitionName ) ->
                                        { modulePath = String.join "/" modulePath
                                        , recordName = definitionName
                                        }
                                            |> Just

                            _ ->
                                Nothing

                    _ ->
                        Nothing
            )


extractDefinitions : Elm.Syntax.File.File -> Result String (List RecordDef)
extractDefinitions file =
    file.declarations
        |> List.filterMap
            (\dec ->
                case Node.value dec of
                    AliasDeclaration p ->
                        case Node.value p.typeAnnotation of
                            Record xs ->
                                let
                                    name =
                                        Node.value p.name
                                in
                                if name == "PortResult" then
                                    Nothing

                                else
                                    recordEntries xs
                                        |> Result.map
                                            (\val ->
                                                { name = name
                                                , body = buildInterface name val
                                                }
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


buildFile : List String -> List RecordDef -> String
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
                            .body
                            defsData
                        )
                    ++ "\n"
                , ", "
                    ++ String.join ", "
                        (List.map
                            .name
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


buildInterface : String -> List String -> String
buildInterface name xs =
    "interface "
        ++ name
        ++ " {\n  "
        ++ (xs
                |> String.join "\n  "
           )
        ++ "\n}"


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
