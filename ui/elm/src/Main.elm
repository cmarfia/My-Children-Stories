port module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Flags exposing (Flags)
import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Decode
import Json.Encode
import Page exposing (Page)
import Page.Dashboard
import Page.EditStory
import Page.Home
import Page.NotFound
import Page.Story
import Port
import Route exposing (Route)
import Story
import Tuple
import Url exposing (Url)



-- MODEL


type Model
    = InitializationError String
    | Viewing Nav.Key (List Story.Info) Page


init : Json.Decode.Value -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flagsValue url navKey =
    case Json.Decode.decodeValue Flags.decode flagsValue of
        Ok flags ->
            let
                ( page, cmds ) =
                    initPageFromRoute flags.stories (Route.fromUrl flags.stories url)
            in
            ( Viewing navKey flags.stories page, cmds )

        Err error ->
            ( InitializationError "An error occurred loading the page."
            , Cmd.none
            )



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        viewPage { title, content } toMsg =
            { title = title
            , body = [ Html.map toMsg content ]
            }
    in
    case model of
        InitializationError error ->
            { title = "Stories By Iot"
            , body =
                [ div [ class "page page__error" ]
                    [ div [ class "container" ]
                        [ p [] [ text error ]
                        ]
                    ]
                ]
            }

        -- { title = "Stories By Iot"
        -- , body =
        --     [ div [ class "page page__loading" ]
        --         [ div [ class "container" ]
        --             [ div [ class "loading__icon columns" ]
        --                 [ img [ src "img/loading.gif" ] []
        --                 ]
        --             ]
        --         , div [ class "attribution" ]
        --             [ a [ href "https://loading.io/" ] [ text "spinner by loading.io" ]
        --             ]
        --         ]
        --     ]
        -- }
        Viewing navKey stories page ->
            case page of
                Page.NotFound notFoundModel ->
                    viewPage (Page.NotFound.view notFoundModel) GotNotFoundMsg

                Page.Home homeModel ->
                    viewPage (Page.Home.view homeModel) GotHomeMsg

                Page.Story storyModel ->
                    viewPage (Page.Story.view storyModel) GotStoryMsg

                Page.Dashboard dashboardModel ->
                    viewPage (Page.Dashboard.view dashboardModel) GotDashboardMsg

                Page.EditStory editStoryModel ->
                    viewPage (Page.EditStory.view editStoryModel) GotEditStoryMsg



-- UPDATE


type Msg
    = Loaded Bool
    | RequestedUrl Browser.UrlRequest
    | ChangedUrl Url.Url
    | GotNotFoundMsg Page.NotFound.Msg
    | GotHomeMsg Page.Home.Msg
    | GotStoryMsg Page.Story.Msg
    | GotDashboardMsg Page.Dashboard.Msg
    | GotEditStoryMsg Page.EditStory.Msg
    | GotPortMsg Json.Encode.Value


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model of
        InitializationError _ ->
            -- Disregard all messages when an initialization error happens
            ( model, Cmd.none )

        Viewing navKey stories page ->
            case ( msg, page ) of
                ( RequestedUrl urlRequest, _ ) ->
                    case urlRequest of
                        Browser.Internal url ->
                            case url.fragment of
                                Nothing ->
                                    ( model, Cmd.none )

                                Just _ ->
                                    ( model, Nav.pushUrl navKey (Url.toString url) )

                        Browser.External href ->
                            ( model, Nav.load href )

                ( ChangedUrl url, _ ) ->
                    let
                        ( updatedPage, cmds ) =
                            initPageFromRoute stories (Route.fromUrl stories url)
                    in
                    ( Viewing navKey stories updatedPage, cmds )

                ( GotNotFoundMsg subMsg, Page.NotFound notFoundModel ) ->
                    let
                        ( updatedPage, cmds ) =
                            Page.NotFound.update navKey subMsg notFoundModel
                                |> updatePageWith Page.NotFound GotNotFoundMsg
                    in
                    ( Viewing navKey stories updatedPage, cmds )

                ( GotHomeMsg subMsg, Page.Home homeModel ) ->
                    let
                        ( updatedPage, cmds ) =
                            Page.Home.update navKey subMsg homeModel
                                |> updatePageWith Page.Home GotHomeMsg
                    in
                    ( Viewing navKey stories updatedPage, cmds )

                ( GotStoryMsg subMsg, Page.Story storyModel ) ->
                    let
                        ( updatedPage, cmds ) =
                            Page.Story.update navKey subMsg storyModel
                                |> updatePageWith Page.Story GotStoryMsg
                    in
                    ( Viewing navKey stories updatedPage, cmds )

                ( GotDashboardMsg subMsg, Page.Dashboard dashboardModel ) ->
                    let
                        ( updatedPage, cmds ) =
                            Page.Dashboard.update navKey subMsg dashboardModel
                                |> updatePageWith Page.Dashboard GotDashboardMsg
                    in
                    ( Viewing navKey stories updatedPage, cmds )

                ( GotEditStoryMsg subMsg, Page.EditStory editStoryModel ) ->
                    let
                        ( updatedPage, cmds ) =
                            Page.EditStory.update navKey subMsg editStoryModel
                                |> updatePageWith Page.EditStory GotEditStoryMsg
                    in
                    ( Viewing navKey stories updatedPage, cmds )

                ( _, _ ) ->
                    -- Disregard messages that arrived for the wrong page.
                    ( model, Cmd.none )


initPageFromRoute : List Story.Info -> Maybe Route -> ( Page, Cmd Msg )
initPageFromRoute stories maybeRoute =
    case maybeRoute of
        Nothing ->
            Page.NotFound.init stories
                |> updatePageWith Page.NotFound GotNotFoundMsg

        Just Route.Home ->
            Page.Home.init stories
                |> updatePageWith Page.Home GotHomeMsg

        Just (Route.Story story) ->
            Page.Story.init stories story
                |> updatePageWith Page.Story GotStoryMsg

        Just Route.Dashboard ->
            Page.Dashboard.init stories
                |> updatePageWith Page.Dashboard GotDashboardMsg

        Just (Route.EditStory storyId) ->
            Page.EditStory.init stories storyId
                |> updatePageWith Page.EditStory GotEditStoryMsg


updatePageWith : (subModel -> Page) -> (subMsg -> Msg) -> ( subModel, Cmd subMsg ) -> ( Page, Cmd Msg )
updatePageWith toPage toMsg ( subModel, subCmd ) =
    ( toPage subModel
    , Cmd.map toMsg subCmd
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        InitializationError _ ->
            Sub.none

        Viewing _ _ page ->
            let
                pageSubscriptions =
                    case page of
                        Page.NotFound notFoundModel ->
                            Sub.map GotNotFoundMsg <| Page.NotFound.subscriptions notFoundModel

                        Page.Home homeModel ->
                            Sub.map GotHomeMsg <| Page.Home.subscriptions homeModel

                        Page.Story storyModel ->
                            Sub.map GotStoryMsg <| Page.Story.subscriptions storyModel

                        Page.Dashboard dashboardModel ->
                            Sub.map GotDashboardMsg <| Page.Dashboard.subscriptions dashboardModel

                        Page.EditStory editStoryModel ->
                            Sub.map GotEditStoryMsg <| Page.EditStory.subscriptions editStoryModel
            in
            Sub.batch
                [ Port.fromJavaScript GotPortMsg
                , pageSubscriptions
                ]


main : Program Json.Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = ChangedUrl
        , onUrlRequest = RequestedUrl
        }
