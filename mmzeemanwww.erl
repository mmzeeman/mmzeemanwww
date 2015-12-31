%%
%%
%%

-module(mmzeemanwww).
-author("Maas-Maarten Zeeman <mmzeeman@xs4all.nl>").

-mod_title("MMZeeman Site").
-mod_description("The mmzeeman site").
-mod_prio(10).

-export([observe_email_received/2]).

-include_lib("zotonic.hrl").

%%
%% 
observe_email_received(#email_received{email=#email{from= <<"mmzeeman@xs4all.nl">>=From}=Email,
                                       localpart= <<"napiyubzka">>, 
                                       localtags=Localtags}, Context) ->
    %%
    %% Hard coded security string, have to figure out if the rest works out.
    %%

    case m_identity:lookup_by_type_and_key(email, From, Context) of
        undefined ->
            ok;
        Idn ->
            UserId = proplists:get_value(rsc_id, Idn),
            publish_email(Localtags, Email, z_acl:logon(UserId, Context))
    end; 
observe_email_received(_Email, _Context) ->
    ok.

publish_email(Localtags, Email, Context) ->
    {Title, Keywords} = title_and_keywords(Email#email.subject), 

    Body = case Email#email.html of
        Empty when Empty =:= undefined orelse Empty =:= <<>> orelse Empty =:= [] ->
            z_html:nl2br(z_html:escape(Email#email.text));
        Html ->
            z_html:sanitize(Html)
    end,

    Category = category(Localtags, Context), 

    Props = [
       {is_published, true},
       {category, Category},
       {title, Title},
       {body, Body}
    ],

    %% Insert the resource
    %% 
    {ok, RscId} = m_rsc_update:insert(Props, Context),

    %% Make the current user the author of this publication
    %%
    case z_acl:user(Context) of
        undefined -> ok;
        UserId -> m_edge:insert(RscId, author, UserId, Context)
    end,

    connect_attachments(RscId, Email#email.attachments, Context),

    connect_keywords(RscId, Keywords, Context),

    {ok, RscId}.


%% 
%% Helpers
%%

%%
%%
connect_keywords(_RscId, [], _Context) ->
    ok;
connect_keywords(RscId, [Keyword|Rest], Context) ->
    case m_rsc:name_to_id_cat(Keyword, keyword, Context) of
        {ok, KwId} ->
            m_edge:insert(RscId, keyword, KwId, Context);
        _ ->
            %% TODO: Maybe create the keyword?
            no_keyword
    end,
    connect_keywords(RscId, Rest, Context).

%%
%%
connect_attachments(_RscId, [], _Context) ->
    ok;
connect_attachments(RscId, [#upload{}=Upload|Attachments], Context) ->
    AttCategory = upload_category(Upload),
    AttProps = [ {is_published, true}, {category, AttCategory} ],

    try
        {ok, AttId} = m_media:insert_file(Upload, AttProps, Context),
        AttPredicate = case AttCategory of
            image -> depiction;
            _ -> hasdocument
        end,
        m_edge:insert(RscId, AttPredicate, AttId, Context)
    catch
        _:Error ->
            Trace = erlang:get_stacktrace(),

            lager:error("[save_email] error on attachment save for #~p: error ~p", [RscId, Error]),
            lager:error("[save_email] upload was: ~p", [Upload]),
            lager:error("[save_email] stacktrace: ~p", [Trace])
    end,
    connect_attachments(RscId, Attachments, Context).


%%
%%
title_and_keywords(TitleKw) ->
    L = [z_string:trim(S) || S <- binary:split(TitleKw, <<"#">>, [global, trim])],
    [Title | Keywords] = [S || S <- L, S =/= <<>>], 
    {Title, Keywords}.
    


upload_category(#upload{mime= <<"image/", _/binary>>}) -> image;
upload_category(#upload{mime= <<"video/", _/binary>>}) -> video;
upload_category(#upload{mime= <<"audio/", _/binary>>}) -> audio;
upload_category(#upload{mime= <<"application/", _/binary>>}) -> document;
upload_category(#upload{mime=_}) -> media.

%%
%%
category([], _Context) -> text;
category([CatName|_], Context) ->
    case m_category:name_to_id(CatName, Context) of
        {ok, CatId} ->
            CatId;
        _ -> 
            text
    end.
