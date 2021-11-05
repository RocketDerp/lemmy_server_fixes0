use crate::{
  fetcher::object_id::ObjectId,
  objects::person::ApubPerson,
  protocol::{activities::CreateOrUpdateType, objects::chat_message::ChatMessage},
};
use activitystreams::unparsed::Unparsed;
use lemmy_apub_lib::traits::ActivityFields;
use serde::{Deserialize, Serialize};
use url::Url;

#[derive(Clone, Debug, Deserialize, Serialize, ActivityFields)]
#[serde(rename_all = "camelCase")]
pub struct CreateOrUpdatePrivateMessage {
  pub(crate) id: Url,
  pub(crate) actor: ObjectId<ApubPerson>,
  pub(crate) to: [ObjectId<ApubPerson>; 1],
  pub(crate) object: ChatMessage,
  #[serde(rename = "type")]
  pub(crate) kind: CreateOrUpdateType,
  #[serde(flatten)]
  pub(crate) unparsed: Unparsed,
}