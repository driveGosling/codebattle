defmodule Codebattle.Invite do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias __MODULE__
  alias Codebattle.Game.Context
  alias Codebattle.Repo

  @type t :: %__MODULE__{}

  defmodule GameParams do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false
    @timeout_seconds 3600

    @derive {Jason.Encoder, only: [:level, :type, :timeout_seconds]}

    embedded_schema do
      field(:level, :string, default: "elementary")
      field(:type, :string, default: "public")
      field(:timeout_seconds, :integer, default: @timeout_seconds)
    end

    def changeset(struct, params) do
      cast(struct, params, [:level, :type, :timeout_seconds])
    end
  end

  @derive {Jason.Encoder, only: [:id, :state, :creator, :recipient, :game_params, :creator_id, :recipient_id]}

  schema "invites" do
    field(:state, :string, default: "pending")
    belongs_to(:task, Codebattle.Task)
    embeds_one(:game_params, GameParams, on_replace: :update)
    belongs_to(:creator, Codebattle.User)
    belongs_to(:recipient, Codebattle.User)
    belongs_to(:game, Codebattle.Game)
    timestamps()
  end

  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:state, :task_id, :creator_id, :recipient_id, :game_id])
    |> cast_embed(:game_params)
    |> validate_required([:state])
  end

  @spec list_invites() :: [] | [t()]
  def list_invites do
    Invite
    |> Repo.all()
    |> Repo.preload([:creator, :recipient])
  end

  @spec list_active_invites(integer) :: [] | [t()]
  def list_active_invites(user_id) do
    query =
      from(i in Invite,
        where: i.state == "pending" and (i.creator_id == ^user_id or i.recipient_id == ^user_id)
      )

    query
    |> Repo.all()
    |> Repo.preload([:creator, :recipient])
  end

  @spec list_all_active_invites() :: [] | [t()]
  def list_all_active_invites do
    query =
      from(i in Invite,
        where: i.state == "pending"
      )

    query |> Repo.all() |> Repo.preload([:creator, :recipient])
  end

  @spec expire_invite(t()) :: t()
  def expire_invite(invite) do
    Invite.update_invite(invite, %{state: "expired"})
  end

  @spec has_pending_invites?(integer(), integer()) :: boolean()
  def has_pending_invites?(creator_id, recipient_id) do
    users = [creator_id, recipient_id]

    query =
      from(i in Invite,
        where: i.creator_id in ^users and i.recipient_id in ^users and i.state == "pending"
      )

    Repo.exists?(query)
  end

  def get_invite!(id), do: Invite |> Repo.get!(id) |> Repo.preload([:creator, :recipient])

  def create_invite(attrs \\ %{}) do
    %Invite{}
    |> Invite.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, invite} -> {:ok, Repo.preload(invite, [:creator, :recipient])}
      error -> error
    end
  end

  def update_invite(%Invite{} = invite, attrs) do
    invite
    |> Invite.changeset(attrs)
    |> Repo.update()
  end

  def delete_invite(%Invite{} = invite) do
    Repo.delete(invite)
  end

  def change_invite(%Invite{} = invite, attrs \\ %{}) do
    Invite.changeset(invite, attrs)
  end

  def drop_invites_by_users(creator_id, recipient_id) do
    query =
      from(i in Invite,
        where: i.state == "pending" and (i.creator_id == ^creator_id or i.creator_id == ^recipient_id),
        select: i
      )

    Repo.update_all(query, set: [state: "dropped"])
  end

  def accept_invite(params) do
    recipient_id = params.recipient_id
    invite_id = params.id || raise "Not found!"
    invite = get_invite!(invite_id)

    if invite.recipient_id != recipient_id do
      raise "Not authorized!"
    end

    users = [invite.creator, invite.recipient]

    game_params = %{
      players: users,
      state: "playing",
      level: invite.game_params.level,
      type: "duo",
      mode: "standard",
      visibility_type: invite.game_params.type,
      timeout_seconds: invite.game_params.timeout_seconds
    }

    task = invite.task_id && Codebattle.Task.get(invite.task_id)

    game_params =
      if task do
        Map.put(game_params, :task, task)
      else
        game_params
      end

    case Context.create_game(game_params) do
      {:ok, game} ->
        {:ok, invite} = Invite.update_invite(invite, %{state: "accepted", game_id: game.id})

        {_, dropped_invites} =
          Invite.drop_invites_by_users(invite.creator_id, invite.recipient_id)

        {:ok, %{invite: invite, dropped_invites: dropped_invites}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def cancel_invite(params) do
    user_id = params.user_id
    invite_id = params.id || raise "Not found!"
    invite = get_invite!(invite_id)

    if invite.recipient_id != user_id and invite.creator_id != user_id do
      raise "Not authorized!"
    end

    Invite.update_invite(invite, %{state: "canceled"})
  end
end
