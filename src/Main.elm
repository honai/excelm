module Main exposing (main)

import Array exposing (Array)
import Browser
import Browser.Dom
import Browser.Events
import Html exposing (..)
import Html.Attributes as A
import Html.Events as E
import Html.Lazy exposing (lazy3, lazy4)
import Json.Decode as JD
import Task



-- MAIN


main =
    Browser.document
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias CellRef =
    { row : Int
    , col : Int
    }


type alias Table =
    Array (Array Float)


type alias InputState =
    { selected : CellRef
    , isEditing : Bool
    , text : String
    }


type alias Model =
    { table : Table
    , tableSize : CellRef
    , input : InputState
    }


init : String -> ( Model, Cmd Msg )
init _ =
    ( Model
        (Array.repeat 10 (Array.fromList [ 1, 2 ]))
        (CellRef 10 2)
        (InputState (CellRef 0 0) False "")
    , Cmd.none
    )



-- UPDATE


type Move
    = Up
    | Down
    | Left
    | Right


moveCellRef : Move -> CellRef -> CellRef -> CellRef
moveCellRef move cellRef size =
    let
        { row, col } =
            cellRef
    in
    case move of
        Up ->
            { cellRef | row = max 0 (row - 1) }

        Down ->
            { cellRef | row = min (size.row - 1) (row + 1) }

        Left ->
            { cellRef | col = max 0 (col - 1) }

        Right ->
            { cellRef | col = min (size.col - 1) (col + 1) }


type Msg
    = Select CellRef
    | Move Move
    | StartEdit (Maybe CellRef) String
    | CancelEdit
    | Edit String
    | Set
    | None


focusCellEditor : Cmd Msg
focusCellEditor =
    Task.attempt (\_ -> None) (Browser.Dom.focus "cell-input")


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Select cellRef ->
            ( { model | input = InputState cellRef False "" }, Cmd.none )

        Move move ->
            ( { model | input = InputState (moveCellRef move model.input.selected model.tableSize) False "" }, Cmd.none )

        StartEdit (Just cellRef) text ->
            ( { model | input = InputState cellRef True text }, focusCellEditor )

        StartEdit Nothing text ->
            ( { model | input = InputState model.input.selected True text }, focusCellEditor )

        CancelEdit ->
            let
                prevInput =
                    model.input

                newInput =
                    { prevInput | isEditing = False, text = "" }
            in
            ( { model | input = newInput }, Cmd.none )

        Edit text ->
            let
                prevInput =
                    model.input

                newInput =
                    { prevInput | text = text }
            in
            ( { model | input = newInput }, Cmd.none )

        Set ->
            case String.toFloat model.input.text of
                Just num ->
                    let
                        selected =
                            model.input.selected

                        newInput =
                            InputState selected False ""
                    in
                    ( { model
                        | table = updateData selected num model.table
                        , input = newInput
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        None ->
            ( model, Cmd.none )


updateData : CellRef -> Float -> Table -> Table
updateData { row, col } data table =
    case Array.get row table of
        Just rowArray ->
            Array.set row (Array.set col data rowArray) table

        Nothing ->
            table



-- SUBSCRIPTIONS


keyDecoderDown : JD.Decoder Msg
keyDecoderDown =
    JD.map toDirection (JD.field "key" JD.string)


toDirection : String -> Msg
toDirection string =
    case String.length string of
        1 ->
            StartEdit Nothing string

        _ ->
            case string of
                "ArrowLeft" ->
                    Move Left

                "ArrowUp" ->
                    Move Up

                "ArrowRight" ->
                    Move Right

                "ArrowDown" ->
                    Move Down

                "Escape" ->
                    CancelEdit

                "Enter" ->
                    StartEdit Nothing ""

                _ ->
                    None


subscriptions : Model -> Sub Msg
subscriptions { input } =
    if input.isEditing then
        Sub.none

    else
        Browser.Events.onKeyDown keyDecoderDown



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Excel"
    , body = [ viewTable model ]
    }


viewTable : Model -> Html Msg
viewTable model =
    table []
        [ tbody [] (List.indexedMap (lazy3 viewRow model.input) (Array.toList model.table))
        ]


viewRow : InputState -> Int -> Array Float -> Html Msg
viewRow inputState row data =
    tr []
        (List.indexedMap (lazy4 viewCell inputState row) (Array.toList data) ++ [ funcCol data ])


funcCol : Array Float -> Html Msg
funcCol data =
    let
        product =
            Array.foldl (+) 0 data
    in
    td [] [ text <| String.fromFloat <| product ]


viewCell : InputState -> Int -> Int -> Float -> Html Msg
viewCell inputState row col cell =
    let
        cellRef =
            CellRef row col

        isSelected =
            inputState.selected == cellRef

        selectedClass =
            if isSelected then
                "selected"

            else
                ""

        cellText =
            String.fromFloat cell
    in
    if inputState.isEditing && isSelected then
        td [ A.class "selected" ]
            [ form [ E.onSubmit Set ]
                [ input
                    [ A.id "cell-input"
                    , A.value inputState.text
                    , E.onInput Edit
                    , onEscapeKey
                    ]
                    []
                ]
            ]

    else
        td
            [ A.class selectedClass
            , E.onClick (Select cellRef)
            , E.onDoubleClick (StartEdit (Just cellRef) cellText)
            ]
            [ text cellText ]


onEscapeKey : Attribute Msg
onEscapeKey =
    let
        func : String -> Msg
        func key =
            if key == "Escape" then
                CancelEdit

            else
                None
    in
    E.on "keydown" (JD.map func (JD.field "key" JD.string))
