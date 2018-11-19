SET FOREIGN_KEY_CHECKS=0;
ALTER TABLE process DROP FOREIGN KEY process_parent_step;
ALTER TABLE process ADD CONSTRAINT process_parent_step FOREIGN KEY (parent_step) REFERENCES process(id) ON DELETE CASCADE;

ALTER TABLE mobile_subscription_processes DROP FOREIGN KEY `mobile_subsc_subscription_p`;
ALTER TABLE se_application DROP FOREIGN KEY `se_instance_se_application`;
ALTER TABLE se_keyset DROP FOREIGN KEY `se_instance_se_keyset`;
ALTER TABLE se_package DROP FOREIGN KEY `se_instance_se_package`;
ALTER TABLE se_sd DROP FOREIGN KEY `se_instance_se_sd`;
ALTER TABLE service_subscription
DROP FOREIGN KEY `service_subsc_mobile_subscri`,
DROP FOREIGN KEY `service_subsc_se_instance`;

ALTER TABLE mobile_subscription_processes ADD CONSTRAINT `mobile_subsc_subscription_p` FOREIGN KEY (`value`) REFERENCES `process` (`id`) ON DELETE CASCADE;
ALTER TABLE se_application ADD CONSTRAINT `se_instance_se_application` FOREIGN KEY (`value`) REFERENCES `se_instance_application` (`id`) ON DELETE CASCADE;
ALTER TABLE se_keyset ADD CONSTRAINT `se_instance_se_keyset` FOREIGN KEY (`value`) REFERENCES `se_instance_keyset` (`id`) ON DELETE CASCADE;
ALTER TABLE se_package ADD CONSTRAINT `se_instance_se_package` FOREIGN KEY (`value`) REFERENCES `se_instance_package` (`id`) ON DELETE CASCADE;
ALTER TABLE se_sd ADD CONSTRAINT `se_instance_se_sd` FOREIGN KEY (`value`) REFERENCES `se_instance_sd` (`id`) ON DELETE CASCADE;
ALTER TABLE service_subscription
ADD CONSTRAINT `service_subsc_mobile_subscri` FOREIGN KEY (`mobile_subscription`) REFERENCES `mobile_subscription` (`id`) ON DELETE CASCADE,
ADD CONSTRAINT `service_subsc_se_instance` FOREIGN KEY (`se_instance`) REFERENCES `se_instance` (`id`) ON DELETE CASCADE;
ALTER TABLE processErrors ADD CONSTRAINT `process_reference` FOREIGN KEY (`owner`) REFERENCES `process` (`id`) ON DELETE CASCADE;

SET FOREIGN_KEY_CHECKS=1;

DROP PROCEDURE IF EXISTS delete_old_terminated_subscribers;

DELIMITER //

CREATE PROCEDURE delete_old_terminated_subscribers(days INT)

BEGIN

DECLARE remaining_rows INT DEFAULT 0;

SET remaining_rows = (
  SELECT COUNT(DISTINCT ms.id) from mobile_subscription ms
  INNER JOIN mobile_subscription_processes msp
  ON ms.id = msp.owner
  INNER JOIN process p
  ON p.id = msp.value
  WHERE p.end_date IS NOT NULL
  AND TIMESTAMPDIFF(DAY, from_unixtime(p.end_date/1000), now()) > days
  AND p.name = 'CHANGE_LINE_STATUS'
  AND p.status LIKE 'Successfully Completed%'
  AND ms.line_status = 'Terminated'
);

WHILE remaining_rows > 0 DO

drop temporary table if exists tmp_mobile_subscriptions;
create temporary table tmp_mobile_subscriptions(
  SELECT DISTINCT ms.id from mobile_subscription ms
  INNER JOIN mobile_subscription_processes msp
  ON ms.id = msp.owner
  INNER JOIN process p
  ON p.id = msp.value
  WHERE p.end_date IS NOT NULL
  AND TIMESTAMPDIFF(DAY, from_unixtime(p.end_date/1000), now()) > days
  AND p.name = 'CHANGE_LINE_STATUS'
  AND p.status LIKE 'Successfully Completed%'
  AND ms.line_status = 'Terminated'
  LIMIT 1000);

drop temporary table if exists tmp_se_instances;
create temporary table tmp_se_instances(
  SELECT DISTINCT ss.se_instance AS id FROM service_subscription ss
  INNER JOIN tmp_mobile_subscriptions
  ON tmp_mobile_subscriptions.id = ss.mobile_subscription);

DELETE se_instance_application from se_instance_application
  INNER JOIN se_application
  ON se_instance_application.id = se_application.value
  INNER JOIN tmp_se_instances
  ON tmp_se_instances.id = se_application.owner;
DELETE se_instance_package from se_instance_package
  INNER JOIN se_package
  ON se_instance_package.id = se_package.value
  INNER JOIN tmp_se_instances
  ON tmp_se_instances.id = se_package.owner;
DELETE se_instance_keyset from se_instance_keyset
  INNER JOIN se_keyset
  ON se_instance_keyset.id = se_keyset.value
  INNER JOIN tmp_se_instances
  ON tmp_se_instances.id = se_keyset.owner;
DELETE se_instance_sd from se_instance_sd
  INNER JOIN se_sd
  ON se_instance_sd.id = se_sd.value
  INNER JOIN tmp_se_instances
  ON tmp_se_instances.id = se_sd.owner;
DELETE process from process
  INNER JOIN mobile_subscription_processes
  ON mobile_subscription_processes.value = process.id
  INNER JOIN tmp_mobile_subscriptions
  ON tmp_mobile_subscriptions.id = mobile_subscription_processes.owner;
DELETE mobile_subscription from mobile_subscription
  INNER JOIN tmp_mobile_subscriptions
  ON tmp_mobile_subscriptions.id = mobile_subscription.id;
DELETE se_instance from se_instance
  INNER JOIN tmp_se_instances
  ON tmp_se_instances.id = se_instance.id;

commit;

SET remaining_rows = remaining_rows - (SELECT count(1) from tmp_mobile_subscriptions);

END WHILE;
		


END; //
DELIMITER ;
